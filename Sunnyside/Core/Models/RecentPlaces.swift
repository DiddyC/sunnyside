import Foundation
import CoreLocation

/// The last few places the traveller picked, kept on-device (UserDefaults, CA92.1).
enum RecentPlaces {
    private static let key = "recentPlaces"
    private static let limit = 6

    private struct Entry: Codable {
        let name: String
        let lat: Double
        let lon: Double
        let tz: String?
        var place: PlaceResult {
            PlaceResult(name: name, coordinate: .init(latitude: lat, longitude: lon), timeZone: tz.flatMap(TimeZone.init(identifier:)))
        }
    }

    static func load() -> [PlaceResult] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map(\.place)
    }

    static func add(_ place: PlaceResult) {
        guard place.name != "Current location" else { return }
        var entries = load().filter { $0.name != place.name }
        entries.insert(place, at: 0)
        let trimmed = entries.prefix(limit).map {
            Entry(name: $0.name, lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, tz: $0.timeZone?.identifier)
        }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
