import Foundation
import CoreLocation

struct PlaceResult: Equatable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// Local time zone of the place when known (from MapKit); used only for display.
    var timeZone: TimeZone? = nil
}

struct Journey: Equatable {
    let origin: PlaceResult
    let destination: PlaceResult
    let vehicle: Vehicle
    let departureTime: Date
    /// Trip length entered by the traveller (e.g. from the ticket). Nil → estimate from distance.
    var durationOverride: TimeInterval? = nil

    var distanceKm: Double {
        GeoCalculator.distance(from: origin.coordinate, to: destination.coordinate)
    }

    var estimatedDuration: TimeInterval {
        vehicle.estimatedDuration(distanceKm: distanceKm)
    }

    var duration: TimeInterval { durationOverride ?? estimatedDuration }
    var arrivalTime: Date { departureTime.addingTimeInterval(duration) }

    var isTooShort: Bool { distanceKm < 0.5 }

    var formattedDuration: String { Self.format(duration: duration) }

    static func format(duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let h = totalMinutes / 60, m = totalMinutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }
}
