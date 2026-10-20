import SwiftUI

/// Top-down, nose-up outlines for each vehicle, all fitted into a rect.
/// `body` is filled and tinted; `glass` (windscreen) is drawn darker;
/// `extras` (wings, mirrors, tail) are drawn in the surface colour.
struct VehicleSilhouette {
    let body: Path
    let glass: Path
    let extras: Path
    let seatRows: Int
    /// Vertical band (0…1 of rect height) where seats are placed.
    let seatBand: ClosedRange<CGFloat>
    let seatColumnInset: CGFloat   // fraction of width from each side to seat centre

    static func make(for vehicle: Vehicle, in r: CGRect) -> VehicleSilhouette {
        switch vehicle {
        case .train: return train(r)
        case .bus:   return bus(r)
        case .car:   return car(r)
        case .plane: return plane(r)
        case .ferry: return ferry(r)
        }
    }

    // MARK: Train — long, slight nose taper, carriage joint line
    private static func train(_ r: CGRect) -> VehicleSilhouette {
        var p = Path()
        let c = r.width * 0.18
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.09), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.09))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        var g = Path()
        g.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.035, width: r.width * 0.6, height: r.height * 0.05), cornerSize: CGSize(width: 3, height: 3))
        var e = Path()
        // carriage joint
        e.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.52)); e.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.52))
        return .init(body: p, glass: g, extras: e, seatRows: 6, seatBand: 0.17...0.92, seatColumnInset: 0.27)
    }

    // MARK: Bus — boxy, big windscreen, mirrors
    private static func bus(_ r: CGRect) -> VehicleSilhouette {
        let c = r.width * 0.14
        let p = Path(roundedRect: r, cornerSize: CGSize(width: c, height: c), style: .continuous)
        var g = Path()
        g.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.03, width: r.width * 0.84, height: r.height * 0.075), cornerSize: CGSize(width: 4, height: 4))
        var e = Path()
        let my = r.minY + r.height * 0.12, mw = r.width * 0.11, mh = r.height * 0.035
        e.addRoundedRect(in: CGRect(x: r.minX - mw, y: my, width: mw + 2, height: mh), cornerSize: CGSize(width: 2, height: 2))
        e.addRoundedRect(in: CGRect(x: r.maxX - 2, y: my, width: mw + 2, height: mh), cornerSize: CGSize(width: 2, height: 2))
        return .init(body: p, glass: g, extras: e, seatRows: 6, seatBand: 0.2...0.92, seatColumnInset: 0.27)
    }

    // MARK: Car — bonnet, cabin, boot; two rows; mirrors
    private static func car(_ r: CGRect) -> VehicleSilhouette {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.14), control1: CGPoint(x: r.minX + w * 0.86, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + h * 0.04))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - h * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.14, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.14, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - h * 0.1), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.14))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + h * 0.04), control2: CGPoint(x: r.minX + w * 0.14, y: r.minY))
        p.closeSubpath()
        var g = Path()
        // windscreen (trapezoid) and rear window
        g.move(to: CGPoint(x: r.minX + w * 0.12, y: r.minY + h * 0.34))
        g.addLine(to: CGPoint(x: r.maxX - w * 0.12, y: r.minY + h * 0.34))
        g.addLine(to: CGPoint(x: r.maxX - w * 0.06, y: r.minY + h * 0.44))
        g.addLine(to: CGPoint(x: r.minX + w * 0.06, y: r.minY + h * 0.44))
        g.closeSubpath()
        g.move(to: CGPoint(x: r.minX + w * 0.08, y: r.maxY - h * 0.2))
        g.addLine(to: CGPoint(x: r.maxX - w * 0.08, y: r.maxY - h * 0.2))
        g.addLine(to: CGPoint(x: r.maxX - w * 0.14, y: r.maxY - h * 0.12))
        g.addLine(to: CGPoint(x: r.minX + w * 0.14, y: r.maxY - h * 0.12))
        g.closeSubpath()
        var e = Path()
        let my = r.minY + h * 0.4, mw = w * 0.12, mh = h * 0.03
        e.addRoundedRect(in: CGRect(x: r.minX - mw, y: my, width: mw + 2, height: mh), cornerSize: CGSize(width: 2, height: 2))
        e.addRoundedRect(in: CGRect(x: r.maxX - 2, y: my, width: mw + 2, height: mh), cornerSize: CGSize(width: 2, height: 2))
        return .init(body: p, glass: g, extras: e, seatRows: 2, seatBand: 0.52...0.72, seatColumnInset: 0.28)
    }

    // MARK: Plane — fuselage, swept wings, tailplane
    private static func plane(_ r: CGRect) -> VehicleSilhouette {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.2), control1: CGPoint(x: r.maxX - w * 0.1, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + h * 0.08))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - h * 0.12))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - h * 0.02), control2: CGPoint(x: r.midX + w * 0.25, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY - h * 0.12), control1: CGPoint(x: r.midX - w * 0.25, y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY - h * 0.02))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.2))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + h * 0.08), control2: CGPoint(x: r.minX + w * 0.1, y: r.minY))
        p.closeSubpath()
        var g = Path()
        g.move(to: CGPoint(x: r.midX - w * 0.22, y: r.minY + h * 0.1))
        g.addLine(to: CGPoint(x: r.midX + w * 0.22, y: r.minY + h * 0.1))
        g.addLine(to: CGPoint(x: r.midX + w * 0.3, y: r.minY + h * 0.16))
        g.addLine(to: CGPoint(x: r.midX - w * 0.3, y: r.minY + h * 0.16))
        g.closeSubpath()
        var e = Path()
        let wingY = r.minY + h * 0.38, span = w * 0.75, chord = h * 0.12, sweep = h * 0.2
        for sign in [-1.0, 1.0] {
            let x0 = sign < 0 ? r.minX : r.maxX
            e.move(to: CGPoint(x: x0, y: wingY))
            e.addLine(to: CGPoint(x: x0 + sign * span, y: wingY + sweep))
            e.addLine(to: CGPoint(x: x0 + sign * span, y: wingY + sweep + chord * 0.6))
            e.addLine(to: CGPoint(x: x0, y: wingY + chord + sweep * 0.35))
            e.closeSubpath()
            let tailY = r.maxY - h * 0.1, tspan = w * 0.38
            e.move(to: CGPoint(x: x0, y: tailY - h * 0.02))
            e.addLine(to: CGPoint(x: x0 + sign * tspan, y: tailY + h * 0.05))
            e.addLine(to: CGPoint(x: x0 + sign * tspan, y: tailY + h * 0.09))
            e.addLine(to: CGPoint(x: x0, y: tailY + h * 0.05))
            e.closeSubpath()
        }
        return .init(body: p, glass: g, extras: e, seatRows: 7, seatBand: 0.24...0.84, seatColumnInset: 0.28)
    }

    // MARK: Ferry — pointed bow, rounded stern, deck inset
    private static func ferry(_ r: CGRect) -> VehicleSilhouette {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.3), control1: CGPoint(x: r.midX + w * 0.3, y: r.minY + h * 0.06), control2: CGPoint(x: r.maxX, y: r.minY + h * 0.18))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - h * 0.08))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.2, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.2, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - h * 0.08), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.3))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + h * 0.18), control2: CGPoint(x: r.midX - w * 0.3, y: r.minY + h * 0.06))
        p.closeSubpath()
        var g = Path()   // bridge
        g.addRoundedRect(in: CGRect(x: r.minX + w * 0.3, y: r.minY + h * 0.2, width: w * 0.4, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        var e = Path()   // deck outline
        e.addRoundedRect(in: r.insetBy(dx: w * 0.1, dy: h * 0.06).offsetBy(dx: 0, dy: h * 0.1).insetBy(dx: 0, dy: h * 0.1), cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
        return .init(body: p, glass: g, extras: e, seatRows: 5, seatBand: 0.36...0.9, seatColumnInset: 0.28)
    }
}
