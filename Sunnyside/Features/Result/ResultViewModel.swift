import Foundation
import Observation

/// Thin wrapper: the engine is pure and sub-millisecond, so the result is
/// computed synchronously before the first frame (no spinner).
@MainActor
@Observable
final class ResultViewModel {
    let journey: Journey
    let recommendation: SeatRecommendation

    init(journey: Journey) {
        self.journey = journey
        self.recommendation = SeatEngine.recommend(journey: journey)
    }

    // MARK: Presentation

    var eyebrow: String {
        switch recommendation.verdict {
        case .sitLeft, .sitRight: return "Sit on the"
        case .mixed: return "Sit on"
        case .noSun: return "Sit"
        }
    }

    var headline: String {
        switch recommendation.verdict {
        case .sitLeft: return "LEFT"
        case .sitRight: return "RIGHT"
        case .mixed: return "EITHER"
        case .noSun: return "ANYWHERE"
        }
    }

    var subtitle: String {
        let rec = recommendation
        switch rec.verdict {
        case .sitLeft:
            return "Sun on your right for \(percent(rec.sunRightShare)) of the trip." + crossoverNote
        case .sitRight:
            return "Sun on your left for \(percent(rec.sunLeftShare)) of the trip." + crossoverNote
        case .mixed(let shady):
            if let sw = switchDescription {
                return "The sun crosses over \(sw). Slightly less sun on the \(shady == .left ? "left" : "right")."
            }
            return "Sun's split almost evenly. Pick the view."
        case .noSun:
            return "It's dark the whole way. No sun to dodge."
        }
    }

    /// Appended when the sun changes sides for a meaningful stretch.
    private var crossoverNote: String {
        guard let sw = switchDescription else { return "" }
        return " It crosses over \(sw)."
    }

    var routeLine: String {
        "\(journey.origin.name) → \(journey.destination.name) · \(journey.vehicle.displayName) · \(journey.formattedDuration)"
    }

    /// Sun altitude at departure at the origin, for the sky tint.
    var departureSunAltitude: Double {
        recommendation.samples.first?.altitude ?? -20
    }

    /// Where the sun switches sides (first meaningful switch), e.g. "after about 2 h".
    var switchDescription: String? {
        let sunny = recommendation.meaningfulSegments
        guard sunny.count >= 2 else { return nil }
        let t = sunny[1].start.timeIntervalSince(journey.departureTime)
        return "after about \(Journey.format(duration: t))"
    }

    /// First meaningful crossover: when, and which side becomes the shady one.
    var firstSwitch: (time: Date, newShadySide: SeatSide)? {
        let sunny = recommendation.meaningfulSegments
        guard sunny.count >= 2 else { return nil }
        let seg = sunny[1]
        return (seg.start, seg.sunSide == .right ? .left : .right)
    }

    var shareText: String {
        "\(journey.origin.name) → \(journey.destination.name) by \(journey.vehicle.displayName.lowercased()): sit \(headline.lowercased()). \(subtitle) — Coolside"
    }

    var accessibilitySummary: String {
        "\(eyebrow) \(headline.capitalized). \(subtitle) \(journey.vehicle.displayName) from \(journey.origin.name) to \(journey.destination.name), \(journey.formattedDuration)."
    }

    private func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}
