import SwiftUI

/// Dark translucent capsule counter used in the Home header (streak, XP, coins).
struct StatPill<Icon: View>: View {
    let value: String
    var suffix: String? = nil
    var valueColor: Color
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 5) {
            icon()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            if let suffix {
                Text(suffix)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(Theme.pillFill, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.pillBorder, lineWidth: 1) }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
    }
}

#Preview {
    HStack {
        StatPill(value: "5", valueColor: Theme.streakOrange) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.streakOrange)
        }
        StatPill(value: "840", suffix: "XP", valueColor: Theme.progressCyan) { EmptyView() }
    }
    .padding()
    .background(Color.black)
}
