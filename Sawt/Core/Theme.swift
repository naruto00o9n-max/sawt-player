import SwiftUI

enum SawtTheme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.15)
    static let surfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.21)
    static let accent = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let accentSoft = Color(red: 0.55, green: 0.45, blue: 1.0)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let success = Color(red: 0.25, green: 0.82, blue: 0.55)
    static let danger = Color(red: 0.98, green: 0.35, blue: 0.42)
    static let warning = Color(red: 0.98, green: 0.72, blue: 0.28)

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.26, blue: 0.85), Color(red: 0.10, green: 0.09, blue: 0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.17, blue: 0.42), Color(red: 0.10, green: 0.10, blue: 0.18)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 18
    static let radiusLarge: CGFloat = 26
}

extension View {
    func sawtCard() -> some View {
        self
            .background(SawtTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: SawtTheme.radiusMedium, style: .continuous))
    }
}
