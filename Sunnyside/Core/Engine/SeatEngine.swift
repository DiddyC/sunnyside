import Foundation
import CoreLocation

/// Pure, deterministic seat-side engine. No UI, no I/O.
///
/// Pipeline:
///  1. Sample the route every `samplingInterval` seconds (min 2 samples, capped).
///  2. At each sample compute the *local* heading (tangent of the great circle),
///     the sun's altitude/azimuth, and the sun's azimuth relative to the heading.
///  3. Weight each sample by the direct-sun irradiance on a vertical side window:
///         DNI(altitude) × cos(altitude) × |sin(relativeAzimuth)|
///     A low sun shining straight into the side window is the worst case;
///     a high noon sun hits the roof and is nearly weightless for side seats.
///  4. Aggregate the weights per side, derive the verdict and contiguous segments.
enum SeatEngine {

    struct Options {
        var samplingInterval: TimeInterval = 5 * 60   // 5 min
        var maxSamples: Int = 400
        /// Below this altitude (°) the sun is treated as not meaningfully present
        /// (terrain, haze, buildings). Civil twilight is −6°, so 2° is conservative.
        var minimumAltitude: Double = 2
        /// Share needed for a confident single-side verdict. Below it → .mixed.
        var decisiveShare: Double = 0.60
        /// Minimum total exposure, in "peak-sun hours" (1.0 ≈ one hour of a 30° sun
        /// square on to the window ≈ 490 Wh/m²). 0.1 ≈ six minutes of full glare.
        var minimumExposure: Double = 0.1
    }

    static func recommend(journey: Journey, options: Options = Options()) -> SeatRecommendation {
        let samples = sample(journey: journey, options: options)
        return aggregate(samples: samples, journey: journey, options: options)
    }

    // MARK: Sampling

    static func sample(journey: Journey, options: Options) -> [SunSample] {
        let origin = journey.origin.coordinate
        let destination = journey.destination.coordinate
        let duration = journey.duration
        let count = max(2, min(options.maxSamples, Int(ceil(duration / options.samplingInterval)) + 1))

        return (0..<count).map { i in
            let f = Double(i) / Double(count - 1)
            let t = journey.departureTime.addingTimeInterval(f * duration)
            let pos = GeoCalculator.interpolate(from: origin, to: destination, fraction: f)
            let heading = GeoCalculator.heading(along: origin, to: destination, at: f)
            let sun = SunCalculator.position(date: t, lat: pos.latitude, lon: pos.longitude)
            return SunSample(time: t, coordinate: pos, heading: heading,
                             altitude: sun.altitude, azimuth: sun.azimuth,
                             minimumAltitude: options.minimumAltitude)
        }
    }

    // MARK: Aggregation

    static func aggregate(samples: [SunSample], journey: Journey, options: Options) -> SeatRecommendation {
        // Trapezoid integration of glare over time → exposure in peak-sun hours.
        let dtHours = samples.count > 1
            ? samples[1].time.timeIntervalSince(samples[0].time) / 3600
            : 0
        var sunLeft = 0.0, sunRight = 0.0
        for (i, s) in samples.enumerated() {
            let edge = (i == 0 || i == samples.count - 1) ? 0.5 : 1.0
            let exposure = s.glare * edge * dtHours
            switch s.sunSide {
            case .left:  sunLeft  += exposure
            case .right: sunRight += exposure
            case .none:  break
            }
        }
        let total = sunLeft + sunRight
        let segments = buildSegments(samples: samples, dtHours: dtHours)

        guard total >= options.minimumExposure else {
            return SeatRecommendation(verdict: .noSun, sunLeftShare: 0.5, sunRightShare: 0.5,
                                      totalExposure: total, segments: segments, samples: samples, journey: journey)
        }
        let leftShare = sunLeft / total
        let rightShare = sunRight / total
        let verdict: SeatRecommendation.Verdict
        if rightShare >= options.decisiveShare {
            verdict = .sitLeft
        } else if leftShare >= options.decisiveShare {
            verdict = .sitRight
        } else {
            verdict = .mixed(mostlyShady: rightShare >= leftShare ? .left : .right)
        }
        return SeatRecommendation(verdict: verdict, sunLeftShare: leftShare, sunRightShare: rightShare,
                                  totalExposure: total, segments: segments, samples: samples, journey: journey)
    }

    /// Contiguous runs of the same sun side. `exposure` is in peak-sun hours.
    static func buildSegments(samples: [SunSample], dtHours: Double) -> [SeatRecommendation.Segment] {
        var result: [SeatRecommendation.Segment] = []
        var runStart: SunSample? = nil
        var runSide: SunSample.SunSide = .none
        var runExposure = 0.0
        func close(at end: SunSample) {
            guard let start = runStart else { return }
            result.append(.init(start: start.time, end: end.time, sunSide: runSide, exposure: runExposure))
        }
        for (i, s) in samples.enumerated() {
            if s.sunSide != runSide {
                if i > 0 { close(at: samples[i - 1]) }
                runStart = s; runSide = s.sunSide; runExposure = 0
            }
            runExposure += s.glare * dtHours
        }
        if let last = samples.last { close(at: last) }
        return result
    }
}
