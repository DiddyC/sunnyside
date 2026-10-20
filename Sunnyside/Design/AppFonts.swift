import SwiftUI

// System fonts only: Dynamic Type, no font files to ship, no silent fallbacks.
// The verdict uses SF Pro at a condensed width and black weight, which gives
// the tall "poster" feel the original Bebas Neue design was after.
extension Font {
    /// Big display type (verdict, wordmark). Scales with Dynamic Type via `relativeTo`.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .black, design: .default).width(.condensed)
    }

    /// Small uppercase eyebrow / section label.
    static var eyebrow: Font { .system(.caption, design: .default, weight: .semibold) }
}

extension View {
    /// Letter-spaced uppercase label style used for eyebrows and section titles.
    func eyebrowStyle(color: Color = .textTertiary) -> some View {
        self.font(.eyebrow)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
