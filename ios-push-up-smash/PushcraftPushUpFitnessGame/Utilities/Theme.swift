import SwiftUI

enum Theme {
    static let cyan = Color(hex: 0x27E3FF)
    static let gold = Color(hex: 0xFFC53D)

    // PushcraftPushUpFitnessGame palette
    static let ivory = Color(hex: 0xF5F1E6)
    static let amber = Color(hex: 0xFFAE2A)
    static let amberSoft = Color(hex: 0xFFC24B)
    static let amberDeep = Color(hex: 0xFF8A1E)
    static let streakOrange = Color(hex: 0xFF8A3D)
    static let mist = Color(hex: 0x9DAECB)
    static let progressCyan = Color(hex: 0x3ED6FF)
    static let night = Color(hex: 0x050D1C)
    /// Solid deep navy used as the Towers page background.
    static let towersNavy = Color(hex: 0x0B1426)
    static let cardFill = Color(hex: 0x0B1B33, opacity: 0.78)
    /// Deep navy sampled from the home background art; tints the scrolling content panel.
    static let panelTint = Color(hex: 0x111E3A)
    static let pillFill = Color.black.opacity(0.4)
    static let pillBorder = Color(hex: 0x6E82A6, opacity: 0.55)
    static let panel = Color.black.opacity(0.55)
    static let track = Color(hex: 0x071520).opacity(0.85)

    // Onboarding
    static let obNavy = Color(hex: 0x071D42)
    static let obNavyDeep = Color(hex: 0x030E24)
    static let obCard = Color(hex: 0x0E2649)
    static let obCardBorder = Color.white.opacity(0.12)
    /// Dark brown ink used on amber buttons.
    static let buttonInk = Color(hex: 0x3A2200)
    /// Darker bottom edge under amber buttons.
    static let amberEdge = Color(hex: 0xB0560C)

    // Paywall
    static let paywallBg = Color(hex: 0x0B1830)
    static let paywallGold = Color(hex: 0xFFD232)
    static let paywallGoldDeep = Color(hex: 0xF6B60A)
    static let paywallGoldEdge = Color(hex: 0xB98200)
    static let paywallInk = Color(hex: 0x0B1630)
    static let paywallSlate = Color(hex: 0x3A4B69)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Liquid Glass capsule on iOS 26, material capsule on earlier systems.
    @ViewBuilder
    func pillBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
    }
}
