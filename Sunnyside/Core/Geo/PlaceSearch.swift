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
        completer.resultTypes = [.address, .pointOfInterest]
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
        let coord = item.placemark.coordinate
        return PlaceResult(name: suggestion.title, coordinate: coord)
    }

    // MARK: MKLocalSearchCompleterDelegate

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didUpdateResults results: [MKLocalSearchCompletion]) {
        Task { @MainActor in
            self.suggestions = results.prefix(6).map {
                PlaceSuggestion(id: $0.title + "|" + $0.subtitle, title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
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
