import Foundation
import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class JourneyInputViewModel {

    enum OriginMode: Equatable {
        case currentLocation
        case place
    }
    enum LocationState: Equatable {
        case idle, locating, located, denied, failed
    }

    var originMode: OriginMode = .currentLocation
    var origin: PlaceResult?
    var destination: PlaceResult?
    var vehicle: Vehicle = .train
    var leavesNow = true
    var departureDate = Date()
    var durationOverride: TimeInterval?

    private(set) var locationState: LocationState = .idle
    private(set) var currentLocation: PlaceResult?

    private let locationManager = LocationManager()
    private var hasRequestedLocation = false

    // MARK: Derived

    var effectiveOrigin: PlaceResult? {
        originMode == .currentLocation ? currentLocation : origin
    }

    var canSearch: Bool { effectiveOrigin != nil && destination != nil && !isTooShort }

    var isTooShort: Bool {
        guard let o = effectiveOrigin, let d = destination else { return false }
        return GeoCalculator.distance(from: o.coordinate, to: d.coordinate) < 0.5
    }

    var departureTime: Date { leavesNow ? Date() : departureDate }

    /// Region used to bias place search towards the traveller.
    var searchRegion: MKCoordinateRegion? {
        guard let c = currentLocation?.coordinate ?? origin?.coordinate else { return nil }
        return MKCoordinateRegion(center: c, latitudinalMeters: 300_000, longitudinalMeters: 300_000)
    }

    var originTimeZone: TimeZone { effectiveOrigin?.timeZone ?? .current }

    var estimatedDuration: TimeInterval? {
        guard let o = effectiveOrigin, let d = destination else { return nil }
        return vehicle.estimatedDuration(distanceKm: GeoCalculator.distance(from: o.coordinate, to: d.coordinate))
    }

    var duration: TimeInterval? { durationOverride ?? estimatedDuration }

    func buildJourney() -> Journey? {
        guard let o = effectiveOrigin, let d = destination, !isTooShort else { return nil }
        return Journey(origin: o, destination: d, vehicle: vehicle,
                       departureTime: departureTime, durationOverride: durationOverride)
    }

    // MARK: Actions

    func swapEnds() {
        guard let o = effectiveOrigin, let d = destination else { return }
        originMode = .place
        origin = d
        destination = o
    }

    func useCurrentLocation() {
        originMode = .currentLocation
        origin = nil
        requestCurrentLocationIfNeeded(force: true)
    }

    func set(origin place: PlaceResult) {
        originMode = .place
        origin = place
    }

    func set(destination place: PlaceResult) {
        destination = place
        durationOverride = nil   // a new route invalidates a hand-entered duration
    }

    func select(vehicle v: Vehicle) {
        vehicle = v
        durationOverride = nil
    }

    /// One-shot, idempotent. Safe to call from onAppear more than once.
    func requestCurrentLocationIfNeeded(force: Bool = false) {
        guard force || !hasRequestedLocation else { return }
        hasRequestedLocation = true
        locationState = .locating
        locationManager.requestLocation { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let coord):
                self.currentLocation = PlaceResult(name: "Current location", coordinate: coord, timeZone: .current)
                self.locationState = .located
            case .failure(let error as LocationManager.Failure) where error == .denied:
                self.locationState = .denied
                if self.originMode == .currentLocation { self.originMode = .place }
            case .failure:
                self.locationState = .failed
                if self.originMode == .currentLocation { self.originMode = .place }
            }
        }
    }
}

// MARK: - One-shot CoreLocation helper

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    enum Failure: Error, Equatable { case denied, unavailable }

    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocationCoordinate2D, Error>) -> Void)?
    private var awaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            awaitingAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            finish(.failure(Failure.denied))
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        let c = completion
        completion = nil
        c?(result)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            if let coord { self.finish(.success(coord)) } else { self.finish(.failure(Failure.unavailable)) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(error)) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.awaitingAuthorization else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.awaitingAuthorization = false
                self.manager.requestLocation()
            case .denied, .restricted:
                self.awaitingAuthorization = false
                self.finish(.failure(Failure.denied))
            default:
                break   // still .notDetermined (dialog open)
            }
        }
    }
}
