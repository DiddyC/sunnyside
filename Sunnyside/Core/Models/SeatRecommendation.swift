import Foundation

struct SeatRecommendation {
    enum Verdict: Equatable {
        case sitLeft
        case sitRight
        /// Sun changes sides a lot; `mostlyShady` is the side with the lower glare total.
        case mixed(mostlyShady: SeatSide)
        case noSun
    }
    struct Segment: Equatable {
        let start: Date
        let end: Date
        let sunSide: SunSample.SunSide
        let exposure: Double          // peak-sun hours
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    let verdict: Verdict
    let sunLeftShare: Double     // 0…1 share of glare with the sun on the LEFT
    let sunRightShare: Double    // 0…1 share of glare with the sun on the RIGHT
    let totalExposure: Double    // peak-sun hours over the whole trip
    let segments: [Segment]
    let samples: [SunSample]
    let journey: Journey

    var hasAnySun: Bool { verdict != .noSun }

    /// Sunny segments that carry a meaningful share of the trip's exposure.
    var meaningfulSegments: [Segment] {
        let floor = max(0.05, totalExposure * 0.15)
        return segments.filter { $0.sunSide != .none && $0.exposure >= floor }
    }

    /// The side to sit on, if there is a single answer.
    var seatSide: SeatSide? {
        switch verdict {
        case .sitLeft: return .left
        case .sitRight: return .right
        case .mixed(let s): return s
        case .noSun: return nil
        }
    }
    var isDecisive: Bool { if case .mixed = verdict { return false }; return hasAnySun }

    var headline: String {
        switch verdict {
        case .sitLeft: return "LEFT"
        case .sitRight: return "RIGHT"
        case .mixed: return "EITHER"
        case .noSun: return "ANY SEAT"
        }
    }
}
