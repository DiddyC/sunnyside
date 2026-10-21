import Foundation

enum Vehicle: String, CaseIterable, Identifiable, Codable {
    case train, bus, car, plane, ferry

    var id: String { rawValue }

    /// Typical average speed, km/h, used only to *estimate* duration
    /// when the traveller hasn't entered one.
    var averageSpeedKmh: Double {
        switch self {
        case .bus:   return 70
        case .train: return 100
        case .car:   return 90
        case .plane: return 800   // block speed incl. taxi/climb, not cruise
        case .ferry: return 35
        }
    }

    /// Fixed overhead added to the estimate (boarding, taxi, climb-out…).
    var overhead: TimeInterval {
        switch self {
        case .plane: return 25 * 60
        case .ferry: return 10 * 60
        default:     return 0
        }
    }

    var displayName: String {
        switch self {
        case .bus:   return "Bus"
        case .train: return "Train"
        case .car:   return "Car"
        case .plane: return "Plane"
        case .ferry: return "Ferry"
        }
    }

    var systemIcon: String {
        switch self {
        case .bus:   return "bus.fill"
        case .train: return "tram.fill"
        case .car:   return "car.fill"
        case .plane: return "airplane"
        case .ferry: return "ferry.fill"
        }
    }

    func estimatedDuration(distanceKm: Double) -> TimeInterval {
        distanceKm / averageSpeedKmh * 3600 + overhead
    }
}
