import SwiftUI

// MARK: - Card style

extension View {
    /// Slightly lighter navy surface with a subtle blue border, used for all
    /// battle cards.
    func battleCardStyle() -> some View {
        self
            .background(
                Color(hex: 0x121F3A),
                in: .rect(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color(hex: 0x2B3D63), lineWidth: 1)
            }
    }

    /// Recessed darker inset used for the battle code row and text input.
    func recessedFieldStyle() -> some View {
        self
            .background(Color.black.opacity(0.28), in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

// MARK: - Gold button

/// Full-width gold-to-orange button with dark text, shared across the Battles flow.
struct GoldButton<Icon: View>: View {
    let title: String
    var isLoading = false
    @ViewBuilder var icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(Color(hex: 0x3A2200))
                } else {
                    icon()
                }
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: 0x3A2200))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                .linearGradient(
                    colors: [Theme.amberSoft, Theme.amberDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Theme.amberDeep.opacity(0.4), radius: 12, y: 5)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isLoading)
    }
}

extension GoldButton where Icon == EmptyView {
    init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, isLoading: isLoading, icon: { EmptyView() }, action: action)
    }
}

// MARK: - Avatar

/// Circular opponent avatar: their photo when shared, otherwise initials, or a
/// person glyph while waiting for an opponent.
struct BattleAvatar: View {
    let name: String?
    var avatarPath: String? = nil
    var size: CGFloat = 44

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    .linearGradient(
                        colors: [Color(hex: 0x33456B), Color(hex: 0x1C2A47)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(.circle)
            } else if let initials {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.mist)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1) }
        .task(id: avatarPath) {
            guard let avatarPath else {
                image = nil
                return
            }
            image = await AvatarCache.shared.image(for: avatarPath)
        }
    }

    private var initials: String? {
        guard let name, !name.isEmpty else { return nil }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

// MARK: - Outcome colors

extension BattleOutcome {
    var color: Color {
        switch self {
        case .victory: Color(hex: 0x3DDC84)
        case .defeat: Color(hex: 0xFF6B6B)
        case .draw, .expired: Theme.mist
        }
    }
}
