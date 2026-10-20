import SwiftUI

/// The sun's path around the vehicle for the whole trip, vehicle-relative:
/// a polar sky plot where the angle is the sun's bearing relative to the
/// direction of travel (ahead = up, right = right) and the radius is its height
/// (horizon on the ring, overhead near the vehicle). A slider scrubs through
/// the trip; the sun marker and caption follow.
struct SunCompassView: View {
    let recommendation: SeatRecommendation
    @Binding var progress: Double      // 0 = departure … 1 = arrival

    private var samples: [SunSample] { recommendation.samples }
    private var journey: Journey { recommendation.journey }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let ring = side / 2 - 22            // horizon radius (labels sit outside it)
            let inner = ring * 0.56             // zenith radius
            let vehicleRect = CGRect(x: center.x - inner * 0.42, y: center.y - inner * 0.9, width: inner * 0.84, height: inner * 1.8)

            ZStack {
                Canvas { ctx, _ in
                    drawRing(ctx: &ctx, center: center, ring: ring, inner: inner)
                    drawTrail(ctx: &ctx, center: center, ring: ring, inner: inner)
                }
                SeatMapView(vehicle: journey.vehicle, recommendation: recommendation, compact: true)
                    .frame(width: vehicleRect.width, height: vehicleRect.height)
                    .position(x: vehicleRect.midX, y: vehicleRect.midY)
                // compass labels
                compassLabel("Ahead").position(x: center.x, y: center.y - ring - 13)
                compassLabel("Behind").position(x: center.x, y: center.y + ring + 13)
                sideLabel("Left", side: .left).position(x: center.x - ring - 12, y: center.y)
                sideLabel("Right", side: .right).position(x: center.x + ring + 12, y: center.y)
                // sun marker
                marker(center: center, ring: ring, inner: inner)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sun compass. \(caption)")
        .accessibilityValue(timeString(at: progress))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: progress = min(1, progress + 0.05)
            case .decrement: progress = max(0, progress - 0.05)
            @unknown default: break
            }
        }
    }

    // MARK: Geometry

    /// Point on the plot for a vehicle-relative azimuth (° clockwise from ahead) and altitude.
    private func point(relAz: Double, altitude: Double, center: CGPoint, ring: CGFloat, inner: CGFloat) -> CGPoint {
        let a = (relAz - 90) * .pi / 180
        let r: CGFloat
        if altitude >= 0 {
            r = inner + (ring - inner) * CGFloat(1 - min(altitude, 90) / 90)
        } else {
            r = ring + 7   // just outside the horizon
        }
        return CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
    }

    /// Interpolated sun state at trip fraction `t`.
    private func state(at t: Double) -> (relAz: Double, altitude: Double, glare: Double, side: SunSample.SunSide)? {
        guard samples.count > 1 else { return samples.first.map { ($0.relativeAzimuth, $0.altitude, $0.glare, $0.sunSide) } }
        let pos = max(0, min(1, t)) * Double(samples.count - 1)
        let i = Int(pos.rounded(.down)), f = pos - Double(i)
        let a = samples[i], b = samples[min(i + 1, samples.count - 1)]
        var dAz = b.relativeAzimuth - a.relativeAzimuth
        if dAz > 180 { dAz -= 360 } else if dAz < -180 { dAz += 360 }
        let az = (a.relativeAzimuth + dAz * f + 360).truncatingRemainder(dividingBy: 360)
        let alt = a.altitude + (b.altitude - a.altitude) * f
        let glare = a.glare + (b.glare - a.glare) * f
        let side: SunSample.SunSide = alt < a.minimumAltitude ? .none : (az < 180 ? .right : .left)
        return (az, alt, glare, side)
    }

    // MARK: Drawing

    private func drawRing(ctx: inout GraphicsContext, center: CGPoint, ring: CGFloat, inner: CGFloat) {
        let horizon = Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
        ctx.stroke(horizon, with: .color(Color.appBorder), lineWidth: 1.5)
        // 45° altitude guide
        let mid = inner + (ring - inner) * 0.5
        let guide = Path(ellipseIn: CGRect(x: center.x - mid, y: center.y - mid, width: mid * 2, height: mid * 2))
        ctx.stroke(guide, with: .color(Color.appBorder.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        // cross hairs
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - ring, y: center.y)); cross.addLine(to: CGPoint(x: center.x + ring, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - ring)); cross.addLine(to: CGPoint(x: center.x, y: center.y + ring))
        ctx.stroke(cross, with: .color(Color.appBorder.opacity(0.35)), lineWidth: 1)
    }

    private func drawTrail(ctx: inout GraphicsContext, center: CGPoint, ring: CGFloat, inner: CGFloat) {
        // A trip with no usable sun gets the plain seat map; the night-time trail adds nothing.
        guard samples.count > 1, recommendation.hasAnySun else { return }
        // Segments: sunlit runs as amber strokes weighted by glare; dark runs as dashed grey outside the ring.
        var i = 0
        while i < samples.count - 1 {
            let lit = samples[i].hasSun
            var p = Path()
            p.move(to: point(relAz: samples[i].relativeAzimuth, altitude: samples[i].altitude, center: center, ring: ring, inner: inner))
            var j = i + 1
            var maxGlare = samples[i].glare
            while j < samples.count && samples[j].hasSun == lit {
                p.addLine(to: point(relAz: samples[j].relativeAzimuth, altitude: samples[j].altitude, center: center, ring: ring, inner: inner))
                maxGlare = max(maxGlare, samples[j].glare)
                j += 1
            }
            if lit {
                ctx.stroke(p, with: .color(Color.sunAmber.opacity(0.25 + 0.65 * maxGlare)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            } else {
                ctx.stroke(p, with: .color(Color.textTertiary.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
            }
            i = max(j - 1, i + 1)
        }
        // Sunrise / sunset marks where the sun crosses the horizon
        for k in 1..<samples.count where samples[k].hasSun != samples[k - 1].hasSun {
            let s = samples[k]
            let pt = point(relAz: s.relativeAzimuth, altitude: 0, center: center, ring: ring, inner: inner)
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)), with: .color(Color.sunAmber))
            let label = (s.hasSun ? "rise " : "set ") + timeString(at: Double(k) / Double(samples.count - 1))
            let dir = CGPoint(x: pt.x - center.x, y: pt.y - center.y)
            let len = max(1, hypot(dir.x, dir.y))
            let at = CGPoint(x: pt.x + dir.x / len * 16, y: pt.y + dir.y / len * 12)
            ctx.draw(Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.textSecondary), at: at)
        }
        // departure & arrival dots
        for (k, name) in [(0, "dep"), (samples.count - 1, "arr")] {
            let s = samples[k]
            let pt = point(relAz: s.relativeAzimuth, altitude: s.altitude, center: center, ring: ring, inner: inner)
            ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)), with: .color(Color.textSecondary), lineWidth: 1.5)
            _ = name
        }
    }

    @ViewBuilder
    private func marker(center: CGPoint, ring: CGFloat, inner: CGFloat) -> some View {
        if recommendation.hasAnySun, let s = state(at: progress) {
            let pt = point(relAz: s.relAz, altitude: s.altitude, center: center, ring: ring, inner: inner)
            ZStack {
                if s.altitude >= 0 {
                    Circle()
                        .fill(RadialGradient(colors: [Color.sunAmber.opacity(0.2 + 0.4 * s.glare), .clear], center: .center, startRadius: 0, endRadius: 30))
                        .frame(width: 60, height: 60)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.sunAmber)
                        .shadow(color: Color.sunGlow.opacity(0.6), radius: 6)
                } else {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .position(pt)
            .animation(.easeOut(duration: 0.08), value: progress)
        }
    }

    private func compassLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 9, weight: .bold)).textCase(.uppercase).tracking(1).foregroundStyle(Color.textTertiary)
    }

    private func sideLabel(_ t: String, side: SeatSide) -> some View {
        let shady = recommendation.seatSide == side
        let sunny = recommendation.hasAnySun && !shady
        return VStack(spacing: 1) {
            Text(t).font(.system(size: 10, weight: .bold))
                .foregroundStyle(shady ? Color.shadeBlue : (sunny ? Color.sunText : Color.textTertiary))
            if recommendation.hasAnySun {
                Text(shady ? "shade" : "sun").font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(shady ? Color.shadeBlue.opacity(0.85) : Color.sunText.opacity(0.85))
            }
        }
        .rotationEffect(.degrees(side == .left ? -90 : 90))
    }

    // MARK: Text

    private var formatter: DateFormatter {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        f.timeZone = journey.origin.timeZone ?? .current
        return f
    }

    func timeString(at t: Double) -> String {
        formatter.string(from: journey.departureTime.addingTimeInterval(t * journey.duration))
    }

    /// One-line description of the sun at the current scrub position.
    var caption: String {
        guard let s = state(at: progress) else { return "" }
        if s.altitude < 0 { return "Below the horizon" }
        let where_: String
        switch s.relAz {
        case 0..<20, 340..<360: where_ = "straight ahead"
        case 20..<70:   where_ = "ahead on your right"
        case 70..<110:  where_ = "on your right"
        case 110..<160: where_ = "behind on your right"
        case 160..<200: where_ = "straight behind"
        case 200..<250: where_ = "behind on your left"
        case 250..<290: where_ = "on your left"
        default:        where_ = "ahead on your left"
        }
        let height = s.altitude < 10 ? "very low" : s.altitude < 30 ? "low" : s.altitude < 55 ? "mid-sky" : "high"
        return "Sun \(where_), \(height) (\(Int(s.altitude.rounded()))°)"
    }
}
