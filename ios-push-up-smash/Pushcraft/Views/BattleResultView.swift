import SwiftUI

/// Result screen for a finished battle: Victory, Defeat, Draw or Expired with
/// both scores, and a return to the Battles page (Completed tab).
struct BattleResultView: View {
    let battleID: UUID
    var onBackToBattles: () -> Void

    @Environment(AppState.self) private var appState

    private var battle: Battle? { appState.battles.battle(withID: battleID) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A1730), Theme.night], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let battle, let result = battle.result {
                        outcomeHeader(result)
                        opponentLine(battle)

                        scoreCard(battle, result: result)
                            .padding(.top, 6)

                        Text(footnote(battle, result: result))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else {
                        ProgressView().tint(Theme.amberSoft).padding(.top, 80)
                        Text("The result isn't final yet.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }

                    GoldButton(title: "Back to Battles") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                    } action: {
                        onBackToBattles()
                    }
                    .padding(.top, 10)
                }
                .padding(16)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .task { try? await appState.battles.load() }
    }

    private func footnote(_ battle: Battle, result: BattleResult) -> String {
        let date = result.date.formatted(date: .abbreviated, time: .omitted)
        switch result.outcome {
        case .expired:
            return "Expired \(date) · no scores were submitted in time"
        default:
            if result.myScore == nil || result.opponentScore == nil {
                return "Decided \(date) · the other player didn't submit before the deadline"
            }
            return "Completed \(date)"
        }
    }

    // MARK: - Sections

    private func outcomeHeader(_ result: BattleResult) -> some View {
        VStack(spacing: 10) {
            Image(systemName: iconName(result.outcome))
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(result.outcome.color)
            Text(result.outcome.title)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(result.outcome.color)
        }
    }

    private func opponentLine(_ battle: Battle) -> some View {
        Text("vs \(battle.opponentName ?? "No opponent")")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.mist)
    }

    private func scoreCard(_ battle: Battle, result: BattleResult) -> some View {
        HStack(spacing: 0) {
            scoreColumn(label: "YOU", score: result.myScore, unit: battle.exercise.unitName, color: Theme.progressCyan)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 56)
            scoreColumn(
                label: (battle.opponentName ?? "OPPONENT").uppercased(),
                score: result.opponentScore,
                unit: battle.exercise.unitName,
                color: Theme.mist
            )
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .battleCardStyle()
    }

    private func scoreColumn(label: String, score: Int?, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
            Text(score.map(String.init) ?? "—")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(score == nil ? "no score" : unit)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private func iconName(_ outcome: BattleOutcome) -> String {
        switch outcome {
        case .victory: "trophy.fill"
        case .defeat: "xmark.circle.fill"
        case .draw: "equal.circle.fill"
        case .expired: "hourglass"
        }
    }
}
