import SwiftUI

/// Top-corner counter (REPS / COINS) that bumps whenever its value changes.
struct StatCard<Icon: View>: View {
    let value: Int
    let label: String
    let tint: Color
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(spacing: 8) {
            icon()
            VStack(alignment: .leading, spacing: -2) {
                Text("\(value)")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy, value: value)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 94, alignment: .leading)
        .background(Theme.panel, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint, lineWidth: 2)
                .shadow(color: tint.opacity(0.8), radius: 6)
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: value) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.14, duration: 0.08)
            SpringKeyframe(1, duration: 0.3, spring: .bouncy)
        }
        .accessibilityElement(children: .combine)
    }
}
