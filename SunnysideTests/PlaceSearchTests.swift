import XCTest
import MapKit
@testable import Sunnyside

/// Integration tests against Apple Maps (network). They verify the completer
/// configuration actually returns results for the kind of input travellers type.
@MainActor
final class PlaceSearchTests: XCTestCase {

    private func waitForSuggestions(_ search: PlaceSearch, timeout: TimeInterval = 12) async -> [PlaceSuggestion] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !search.suggestions.isEmpty { return search.suggestions }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return search.suggestions
    }

    func testCityNameCompletes() async throws {
        let search = PlaceSearch()
        search.update(query: "haifa")
        let results = await waitForSuggestions(search)
        XCTAssertFalse(results.isEmpty, "no completions for 'haifa' (isSearching=\(search.isSearching))")
        XCTAssertTrue(results.contains { $0.title.lowercased().contains("haifa") }, "got \(results.map(\.fullText))")
    }

    func testCityNameCompletesWithRegionBias() async throws {
        let search = PlaceSearch()
        search.region = MKCoordinateRegion(center: .init(latitude: 32.08, longitude: 34.78), latitudinalMeters: 300_000, longitudinalMeters: 300_000)
        search.update(query: "haifa")
        let results = await waitForSuggestions(search)
        XCTAssertFalse(results.isEmpty, "no completions with region bias (isSearching=\(search.isSearching))")
    }

    func testStationCompletesAndResolves() async throws {
        let search = PlaceSearch()
        search.region = MKCoordinateRegion(center: .init(latitude: 32.08, longitude: 34.78), latitudinalMeters: 300_000, longitudinalMeters: 300_000)
        search.update(query: "Tel Aviv Savidor")
        let results = await waitForSuggestions(search)
        guard let first = results.first else { return XCTFail("no completions for the station") }
        let place = try await search.resolve(first)
        XCTAssertEqual(place.coordinate.latitude, 32.08, accuracy: 0.3)
        XCTAssertEqual(place.coordinate.longitude, 34.8, accuracy: 0.3)
        XCTAssertNotNil(place.timeZone)
    }
}
