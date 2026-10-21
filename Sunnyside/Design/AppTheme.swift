import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 18
    static let fieldCorner: CGFloat  = 14
    static let pillCorner: CGFloat   = 100
    static let cardPadding: CGFloat  = 18
    static let screenGutter: CGFloat = 20
}

struct SurfaceCard: ViewModifier {
    var elevated: Bool = false
    var padding: CGFloat = AppTheme.cardPadding
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(elevated ? Color.appSurfaceElevated : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.appBorder.opacity(0.7), lineWidth: 1)
            )
    }
}

extension View {
    /// Card chrome *including* its inner padding (padding is applied inside the card).
    func surfaceCard(elevated: Bool = false, padding: CGFloat = AppTheme.cardPadding) -> some View {
        modifier(SurfaceCard(elevated: elevated, padding: padding))
    }
}

/// Primary amber pill button.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .bold))
            .foregroundStyle(isEnabled ? Color.appBackground : Color.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(isEnabled ? Color.sunAmber : Color.appSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isEnabled ? Color.clear : Color.appBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
