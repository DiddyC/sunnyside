import SwiftUI
import CoreLocation

@main
struct SunnysideApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Applies the Appearance setting to the whole window and picks the entry screen.
struct RootView: View {
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.dark.rawValue

    var body: some View {
        Group {
            if let demo = DemoJourney.fromLaunchArguments() {
                NavigationStack { ResultView(journey: demo) }
            } else {
                JourneyInputView()
            }
        }
        .tint(.sunText)
        .preferredColorScheme((Appearance(rawValue: appearanceRaw) ?? .dark).colorScheme)
        .task { if Monetization.enabled { await Entitlements.shared.refresh() } }
    }
}

/// Canned journeys for previews and screenshots. Launch with `-demo left|right|switch|mixed|night|plane`.
/// Add `-appearance light` to force the light look.
enum DemoJourney {
    static func fromLaunchArguments() -> Journey? {
        let args = ProcessInfo.processInfo.arguments
        if let a = args.firstIndex(of: "-appearance"), a + 1 < args.count {
            UserDefaults.standard.set(args[a + 1], forKey: Appearance.storageKey)
        }
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return nil }
        return journey(named: args[i + 1])
    }

    static func journey(named name: String) -> Journey? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
        }
        let paris = TimeZone(identifier: "Europe/Paris")
        let berlin = TimeZone(identifier: "Europe/Berlin")
        switch name {
        case "left":   // Paris → Strasbourg, winter morning, sun on the right
            return Journey(origin: PlaceResult(name: "Paris Gare de l'Est", coordinate: .init(latitude: 48.877, longitude: 2.359), timeZone: paris),
                           destination: PlaceResult(name: "Strasbourg", coordinate: .init(latitude: 48.585, longitude: 7.734), timeZone: paris),
                           vehicle: .train, departureTime: utc(2026, 12, 15, 8, 0), durationOverride: 1 * 3600 + 46 * 60)
        case "right":  // Strasbourg → Paris, same morning
            return Journey(origin: PlaceResult(name: "Strasbourg", coordinate: .init(latitude: 48.585, longitude: 7.734), timeZone: paris),
                           destination: PlaceResult(name: "Paris Gare de l'Est", coordinate: .init(latitude: 48.877, longitude: 2.359), timeZone: paris),
                           vehicle: .train, departureTime: utc(2026, 12, 15, 8, 0), durationOverride: 1 * 3600 + 46 * 60)
        case "mixed":  // Hamburg → Munich bus, symmetric around solar noon in June
            return Journey(origin: PlaceResult(name: "Hamburg ZOB", coordinate: .init(latitude: 53.553, longitude: 10.010), timeZone: berlin),
                           destination: PlaceResult(name: "Munich", coordinate: .init(latitude: 48.140, longitude: 11.560), timeZone: berlin),
                           vehicle: .bus, departureTime: utc(2026, 6, 21, 6, 30), durationOverride: 8 * 3600 + 30 * 60)
        case "switch": // Hamburg → Munich bus, afternoon-heavy: decisive but crosses over
            return Journey(origin: PlaceResult(name: "Hamburg ZOB", coordinate: .init(latitude: 53.553, longitude: 10.010), timeZone: berlin),
                           destination: PlaceResult(name: "Munich", coordinate: .init(latitude: 48.140, longitude: 11.560), timeZone: berlin),
                           vehicle: .bus, departureTime: utc(2026, 6, 21, 7, 0), durationOverride: 9 * 3600 + 30 * 60)
        case "car":    // Lyon → Marseille by car, late afternoon heading south
            return Journey(origin: PlaceResult(name: "Lyon", coordinate: .init(latitude: 45.764, longitude: 4.836), timeZone: paris),
                           destination: PlaceResult(name: "Marseille", coordinate: .init(latitude: 43.296, longitude: 5.370), timeZone: paris),
                           vehicle: .car, departureTime: utc(2026, 7, 10, 14, 30), durationOverride: 3 * 3600 + 10 * 60)
        case "ferry":  // Piraeus → Mykonos, morning
            return Journey(origin: PlaceResult(name: "Piraeus", coordinate: .init(latitude: 37.942, longitude: 23.646), timeZone: TimeZone(identifier: "Europe/Athens")),
                           destination: PlaceResult(name: "Mykonos", coordinate: .init(latitude: 37.446, longitude: 25.329), timeZone: TimeZone(identifier: "Europe/Athens")),
                           vehicle: .ferry, departureTime: utc(2026, 8, 5, 4, 30), durationOverride: 4 * 3600 + 45 * 60)
        case "night":  // Berlin → Munich overnight
            return Journey(origin: PlaceResult(name: "Berlin Hbf", coordinate: .init(latitude: 52.525, longitude: 13.369), timeZone: berlin),
                           destination: PlaceResult(name: "Munich", coordinate: .init(latitude: 48.140, longitude: 11.560), timeZone: berlin),
                           vehicle: .train, departureTime: utc(2026, 6, 21, 21, 0))
        case "plane":  // JFK → LHR red-eye, dawn over the Atlantic
            return Journey(origin: PlaceResult(name: "New York JFK", coordinate: .init(latitude: 40.641, longitude: -73.778), timeZone: TimeZone(identifier: "America/New_York")),
                           destination: PlaceResult(name: "London Heathrow", coordinate: .init(latitude: 51.470, longitude: -0.454), timeZone: TimeZone(identifier: "Europe/London")),
                           vehicle: .plane, departureTime: utc(2026, 3, 2, 1, 0), durationOverride: 7 * 3600)
        case "dayplane": // Lisbon → Athens, daytime eastbound flight
            return Journey(origin: PlaceResult(name: "Lisbon", coordinate: .init(latitude: 38.774, longitude: -9.134), timeZone: TimeZone(identifier: "Europe/Lisbon")),
                           destination: PlaceResult(name: "Athens", coordinate: .init(latitude: 37.936, longitude: 23.947), timeZone: TimeZone(identifier: "Europe/Athens")),
                           vehicle: .plane, departureTime: utc(2026, 9, 12, 9, 0), durationOverride: 4 * 3600 + 5 * 60)
        default:
            return nil
        }
    }
}
