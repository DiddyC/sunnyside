import SwiftUI

// "Night Train" palette with a light twin. Every colour is an asset-catalog
// colour set with light and dark variants, so the whole app follows the
// Appearance setting (System / Light / Dark) with no per-view work.
// All text colours clear WCAG AA (≥ 4.5:1) on the surfaces they sit on;
// SunAmber is for fills and the 100 pt verdict only, SunText for small amber text.
extension Color {
    static let appBackground      = Color("AppBackground")
    static let appSurface         = Color("AppSurface")
    static let appSurfaceElevated = Color("AppSurfaceElevated")
    static let appBorder          = Color("AppBorder")
    static let seatFill           = Color("SeatFill")

    static let sunAmber           = Color("SunAmber")    // fills, CTA, selection, verdict
    static let sunText            = Color("SunText")     // small amber text and links
    static let sunGlow            = Color("SunGlow")
    static let shadeBlue          = Color("ShadeBlue")   // shade side, cool

    static let textPrimary        = Color("TextPrimary")
    static let textSecondary      = Color("TextSecondary")
    static let textTertiary       = Color("TextTertiary")
    static let danger             = Color("Danger")

    /// Sky tint for the departure moment, from the sun's altitude at the origin.
    static func skyTint(sunAltitude: Double) -> Color {
        switch sunAltitude {
        case ..<(-6):  return Color(hex: "#4C6BE0")   // night: cool blue
        case -6..<8:   return Color(hex: "#FF7A59")   // dawn / dusk
        case 8..<35:   return Color(hex: "#F2A93B")   // low sun
        default:       return Color(hex: "#FFD166")   // high sun
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double((int >> 0)  & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
