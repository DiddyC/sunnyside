import SwiftUI

/// Horizontal timeline from departure to arrival. Two lanes: sun on the left /
/// sun on the right. Segments fill the lane where the sun is; bar height is the
/// glare strength. Switch points are labelled with local time.
struct RouteStripView: View {
    let recommendation: SeatRecommendation

    private var journey: Journey { recommendation.journey }
    private var samples: [SunSample] { recommendation.samples }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        f.timeZone = journey.origin.timeZone ?? .current
        return f
    }

    var body: some View {
        VStack(spacing: 8) {
            lane(side: .left)
            lane(side: .right)
            timeAxis
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func lane(side: SunSample.SunSide) -> some View {
        HStack(spacing: 10) {
            Text(side == .left ? "Sun left" : "Sun right")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 58, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.appSurfaceElevated).frame(height: h)
                    Canvas { ctx, _ in
                        guard samples.count > 1 else { return }
                        let n = samples.count
                        let colW = w / CGFloat(n - 1)
                        // One filled area per contiguous run of samples with the sun on this side.
                        var run: [(x: CGFloat, y: CGFloat)] = []
                        func flush() {
                            guard run.count > 1 else { run.removeAll(); return }
                            var p = Path()
                            p.move(to: CGPoint(x: run[0].x, y: h))
                            for pt in run { p.addLine(to: CGPoint(x: pt.x, y: pt.y)) }
                            p.addLine(to: CGPoint(x: run[run.count - 1].x, y: h))
                            p.closeSubpath()
                            ctx.fill(p, with: .linearGradient(
                                Gradient(colors: [Color.sunAmber.opacity(0.95), Color.sunAmber.opacity(0.55)]),
                                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
                            run.removeAll()
                        }
                        for (i, s) in samples.enumerated() {
                            let x = CGFloat(i) * colW
                            if s.sunSide == side && s.glare > 0.02 {
                                if run.isEmpty { run.append((x: max(0, x - colW * 0.5), y: h)) }
                                run.append((x: x, y: h - max(2, h * CGFloat(s.glare))))
                            } else if !run.isEmpty {
                                run.append((x: x - colW * 0.5, y: h))
                                flush()
                            }
                        }
                        flush()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(height: 22)
        }
    }

    private var timeAxis: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 58, height: 1)
            HStack {
                Text("Depart \(timeFormatter.string(from: journey.departureTime))")
                Spacer()
                if let sw = firstSwitch {
                    Text("Switch \(timeFormatter.string(from: sw))").foregroundStyle(Color.sunText)
                    Spacer()
                }
                Text("Arrive \(timeFormatter.string(from: journey.arrivalTime))")
            }
            .font(.system(.caption2, weight: .medium))
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var firstSwitch: Date? {
        let sunny = recommendation.meaningfulSegments
        guard sunny.count >= 2 else { return nil }
        return sunny[1].start
    }

    private var accessibilityText: String {
        let f = timeFormatter
        var parts: [String] = []
        for seg in recommendation.meaningfulSegments {
            parts.append("sun on the \(seg.sunSide == .left ? "left" : "right") from \(f.string(from: seg.start)) to \(f.string(from: seg.end))")
        }
        return parts.isEmpty ? "Little or no sun along the route." : parts.joined(separator: ", ") + "."
    }
}
