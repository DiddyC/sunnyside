import Foundation
import MapKit
import Observation

/// A single autocomplete suggestion from Apple Maps.
struct PlaceSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    var fullText: String { subtitle.isEmpty ? title : "\(title), \(subtitle)" }

    static func == (a: PlaceSuggestion, b: PlaceSuggestion) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Apple Maps autocomplete + geocoding. No API key, no third-party service,
/// results are biased to `region` (the user's surroundings) when known.
@MainActor
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [PlaceSuggestion] = []
    private(set) var isSearching = false
    var region: MKCoordinateRegion? {
        didSet { if let r = region { completer.region = r } }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // All result types: cities and regions arrive as .query/.address completions,
        // stations and airports as points of interest.
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func update(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { cancel(); return }
        isSearching = true
        completer.queryFragment = q
    }

    func cancel() {
        completer.cancel()
        suggestions = []
        isSearching = false
    }

    /// Resolve a suggestion to a coordinate (one MKLocalSearch round trip).
    func resolve(_ suggestion: PlaceSuggestion) async throws -> PlaceResult {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw PlaceSearchError.notFound }
        return PlaceResult(name: suggestion.title, coordinate: item.placemark.coordinate, timeZone: item.timeZone)
    }

    /// Train stations, airports and ferry terminals near a point, nearest first.
    /// Natural-language searches rank real stations above bus stops, which the
    /// generic public-transport category would otherwise fill the list with.
    nonisolated static func nearbyTransit(around center: CLLocationCoordinate2D, radiusMeters: Double = 40_000) async -> [NearbyPlace] {
        let region = MKCoordinateRegion(center: center, latitudinalMeters: radiusMeters * 2, longitudinalMeters: radiusMeters * 2)
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)

        func search(_ query: String, _ categories: [MKPointOfInterestCategory]) async -> [MKMapItem] {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
            return (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        }

        async let stations = search("train station", [.publicTransport])
        async let airports = search("airport", [.airport])
        async let ferries = search("ferry terminal", [.publicTransport])
        let items = await stations + airports + ferries

        var seen = Set<String>()
        let all = items.compactMap { item -> NearbyPlace? in
            guard let name = item.name, seen.insert(name).inserted else { return nil }
            let c = item.placemark.coordinate
            let d = CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: origin)
            guard d <= radiusMeters else { return nil }
            let place = PlaceResult(name: name, coordinate: c, timeZone: item.timeZone)
            return NearbyPlace(place: place, distanceMeters: d, category: item.pointOfInterestCategory)
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }
        // Nearest airport always earns a slot; the rest are the closest stations.
        let airport = all.first { $0.category == .airport }
        let nearestStations = all.filter { $0.category != .airport }.prefix(airport == nil ? 6 : 5)
        return (Array(nearestStations) + [airport].compactMap { $0 }).sorted { $0.distanceMeters < $1.distanceMeters }
    }
}

struct NearbyPlace: Identifiable {
    let place: PlaceResult
    let distanceMeters: Double
    let category: MKPointOfInterestCategory?
    var id: String { "\(place.name)@\(place.coordinate.latitude),\(place.coordinate.longitude)" }

    var icon: String {
        switch category {
        case .airport?: return "airplane"
        case .publicTransport?: return "tram.fill"
        default: return "mappin"
        }
    }
    var distanceText: String {
        distanceMeters < 1000 ? "\(Int(distanceMeters)) m" : String(format: "%.1f km", distanceMeters / 1000)
    }
}

extension PlaceSearch {
    static func nearbyTransit(around center: CLLocationCoordinate2D) async -> [NearbyPlace] {
        await nearbyTransit(around: center, radiusMeters: 30_000)
    }

    // MARK: MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            var seen = Set<String>()
            self.suggestions = results.compactMap { c -> PlaceSuggestion? in
                let id = c.title + "|" + c.subtitle
                guard seen.insert(id).inserted else { return nil }
                return PlaceSuggestion(id: id, title: c.title, subtitle: c.subtitle, completion: c)
            }.prefix(8).map { $0 }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}

enum PlaceSearchError: LocalizedError {
    case notFound
    var errorDescription: String? { "Couldn't find that place. Try a nearby station or address." }
}
