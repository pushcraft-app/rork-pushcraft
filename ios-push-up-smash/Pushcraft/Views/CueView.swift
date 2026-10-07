import SwiftUI

/// Helper text under the depth meter ("GO DOWN TO CHARGE", "PUSH UP — SMASH IT!").
struct CueView: View {
    let cue: CoachCue
    var exercise: Exercise = .pushUps

    var body: some View {
        VStack(spacing: 8) {
            ChevronHint(cue: cue, exercise: exercise)
                .frame(height: 26)

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    if let symbol = cue.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(cue.title(for: exercise))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Theme.panel, in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(cue.tint, lineWidth: 2)
                        .shadow(color: cue.tint.opacity(0.8), radius: 6)
                }

                if let subtitle = cue.subtitle(for: exercise) {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.6), radius: 4)
                        .padding(.top, 4)
                }
            }
            .id(cue)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cue)
    }
}

private struct ChevronHint: View {
    let cue: CoachCue
    let exercise: Exercise

    var body: some View {
        switch cue {
        case .goDown:
            // Push-ups charge sinking, sit-ups charge rising.
            chevrons(down: exercise == .pushUps, color: Theme.cyan)
        case .smashIt:
            chevrons(down: false, color: Theme.gold)
        default:
            Color.clear
        }
    }

    private func chevrons(down: Bool, color: Color) -> some View {
        VStack(spacing: -9) {
            Image(systemName: down ? "chevron.down" : "chevron.up")
            Image(systemName: down ? "chevron.down" : "chevron.up")
        }
        .font(.system(size: 17, weight: .heavy))
        .foregroundStyle(color)
        .shadow(color: color, radius: 6)
        .phaseAnimator([false, true]) { content, phase in
            content
                .offset(y: (phase ? 5 : -3) * (down ? 1 : -1))
                .opacity(phase ? 1 : 0.55)
        } animation: { _ in
            .easeInOut(duration: 0.5)
        }
        .id(down)
    }
}
