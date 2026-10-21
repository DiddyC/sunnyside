import SwiftUI

/// Nose-up vehicle (shape per vehicle type) with two seat columns. Direction of
/// travel is up, like a map and like your body in the seat, so screen-left is
/// the vehicle's left. The shaded column is tinted cool; the sunny column is
/// washed warm. In `compact` mode (inside the sun compass) the labels, sun disc
/// and travel arrow are omitted because the ring supplies them.
struct SeatMapView: View {
    let vehicle: Vehicle
    let recommendation: SeatRecommendation
    var compact = false

    private var seatSide: SeatSide? { recommendation.seatSide }
    private var sunOnRight: Bool { recommendation.sunRightShare >= recommendation.sunLeftShare }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let bodyW = compact ? w * 0.5 : min(w * 0.46, 170)
            let bodyH = compact ? h * 0.92 : h * 0.86
            let bodyRect = CGRect(x: (w - bodyW) / 2, y: (h - bodyH) / 2, width: bodyW, height: bodyH)

            ZStack {
                Canvas { ctx, _ in
                    let s = VehicleSilhouette.make(for: vehicle, in: bodyRect)
                    draw(ctx: &ctx, silhouette: s, rect: bodyRect)
                }
                if !compact {
                    sideLabel("Left", isShady: seatSide == .left, isSunny: recommendation.hasAnySun && !sunOnRight)
                        .position(x: bodyRect.minX - 50, y: bodyRect.midY)
                    sideLabel("Right", isShady: seatSide == .right, isSunny: recommendation.hasAnySun && sunOnRight)
                        .position(x: bodyRect.maxX + 50, y: bodyRect.midY)
                    celestial
                        .position(x: recommendation.hasAnySun
                                  ? (sunOnRight ? bodyRect.maxX + 50 : bodyRect.minX - 50)
                                  : bodyRect.midX,
                                  y: recommendation.hasAnySun ? bodyRect.minY + bodyRect.height * 0.28 : bodyRect.minY - 18)
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.up").font(.system(.caption2, weight: .bold))
                        Text("Travel").font(.system(size: 9, weight: .semibold)).textCase(.uppercase).tracking(1)
                    }
                    .foregroundStyle(Color.textTertiary)
                    .position(x: bodyRect.midX, y: bodyRect.minY - 18)
                    .opacity(recommendation.hasAnySun ? 1 : 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Drawing

    private func draw(ctx: inout GraphicsContext, silhouette s: VehicleSilhouette, rect: CGRect) {
        // extras behind the body (wings, mirrors, tail, deck)
        ctx.fill(s.extras, with: .color(Color.appSurfaceElevated))
        ctx.stroke(s.extras, with: .color(Color.appBorder), lineWidth: 1)

        ctx.fill(s.body, with: .color(Color.appSurfaceElevated))
        if recommendation.hasAnySun {
            ctx.drawLayer { layer in
                layer.clip(to: s.body)
                let sunnyRect = CGRect(x: sunOnRight ? rect.midX : rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height)
                let shadyRect = CGRect(x: sunOnRight ? rect.minX : rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height)
                let strength = max(recommendation.sunLeftShare, recommendation.sunRightShare)
                layer.fill(Path(sunnyRect), with: .linearGradient(
                    Gradient(colors: [Color.sunAmber.opacity(0.45 * strength), Color.sunAmber.opacity(0.08)]),
                    startPoint: CGPoint(x: sunOnRight ? rect.maxX : rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.midX, y: rect.midY)))
                layer.fill(Path(shadyRect), with: .color(Color.shadeBlue.opacity(0.16)))
            }
        }
        ctx.stroke(s.body, with: .color(Color.appBorder), lineWidth: 1.5)
        ctx.fill(s.glass, with: .color(Color.appBackground.opacity(0.75)))

        // aisle
        let top = rect.minY + rect.height * s.seatBand.lowerBound
        let bottom = rect.minY + rect.height * s.seatBand.upperBound
        var aisle = Path()
        aisle.move(to: CGPoint(x: rect.midX, y: top - 8)); aisle.addLine(to: CGPoint(x: rect.midX, y: bottom + 6))
        ctx.stroke(aisle, with: .color(Color.appBorder.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        // seats
        let rows = s.seatRows
        let seatW = rect.width * 0.3
        let step = rows > 1 ? (bottom - top) / CGFloat(rows - 1) : 0
        let seatH = min(22, max(8, step * 0.55))
        for r in 0..<rows {
            let y = rows > 1 ? top + CGFloat(r) * step : (top + bottom) / 2
            for (isLeft, cx) in [(true, rect.minX + rect.width * s.seatColumnInset), (false, rect.maxX - rect.width * s.seatColumnInset)] {
                let seat = CGRect(x: cx - seatW / 2, y: y - seatH / 2, width: seatW, height: seatH)
                let thisSide: SeatSide = isLeft ? .left : .right
                let fill: Color
                if !recommendation.hasAnySun { fill = .seatFill }
                else if seatSide == thisSide { fill = .shadeBlue.opacity(0.9) }
                else { fill = .seatFill.opacity(0.85) }
                ctx.fill(Path(roundedRect: seat, cornerRadius: 4), with: .color(fill))
                let head = CGRect(x: seat.midX - seatW * 0.28, y: seat.minY - 3, width: seatW * 0.56, height: 3)
                ctx.fill(Path(roundedRect: head, cornerRadius: 1.5), with: .color(fill.opacity(0.9)))
            }
        }
    }

    private func sideLabel(_ text: String, isShady: Bool, isSunny: Bool) -> some View {
        VStack(spacing: 3) {
            Text(text)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(isShady ? Color.shadeBlue : (isSunny ? Color.sunText : Color.textTertiary))
            if isShady {
                Text("shade").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.shadeBlue.opacity(0.85))
            } else if isSunny {
                Text("sun").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.sunText.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var celestial: some View {
        if recommendation.hasAnySun {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.sunAmber.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 40))
                    .frame(width: 80, height: 80)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.sunAmber)
                    .shadow(color: Color.sunGlow.opacity(0.7), radius: 10)
            }
        } else {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var accessibilityText: String {
        guard recommendation.hasAnySun else { return "\(vehicle.displayName) seat map. No sun during this trip; sit anywhere." }
        let side = seatSide == .left ? "left" : "right"
        return "\(vehicle.displayName) seat map, direction of travel up. Shaded seats on the \(side). Sun mostly on the \(sunOnRight ? "right" : "left")."
    }
}
