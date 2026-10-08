import SwiftUI

/// The four main sections of PushcraftPushUpFitnessGame.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case towers
    case battles
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .towers: "Towers"
        case .battles: "Battles"
        case .profile: "Profile"
        }
    }

    /// Unselected tab bar artwork (muted blue).
    var iconName: String { "tab-\(rawValue)" }

    /// Selected tab bar artwork (orange).
    var activeIconName: String { "tab-\(rawValue)-active" }
}
