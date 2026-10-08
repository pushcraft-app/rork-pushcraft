import SwiftUI

/// Capsule status badge shown at the top of each tower card.
struct StatusBadgeView: View {
    let status: TowerStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.14), in: .capsule)
        .overlay { Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1) }
    }

    private var label: String {
        switch status {
        case .completed: "COMPLETED"
        case .inProgress: "IN PROGRESS"
        case .locked: "LOCKED"
        }
    }

    private var iconName: String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .inProgress: "circle.dotted"
        case .locked: "lock.fill"
        }
    }

    private var color: Color {
        switch status {
        case .completed: Color(hex: 0x3DDC84)
        case .inProgress: Theme.amberSoft
        case .locked: Color(hex: 0x97A3B8)
        }
    }
}
