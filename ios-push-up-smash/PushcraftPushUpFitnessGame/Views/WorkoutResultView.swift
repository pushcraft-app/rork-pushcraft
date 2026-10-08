import SwiftUI

/// Results after a workout or battle run. Always shows the outcome the
/// server accepted; while offline, the run is kept on the phone and syncs later.
struct WorkoutResultView: View {
    let session: ActiveSession
    let reps: Int
    let state: SubmitState
    var onRetry: () -> Void
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A1730), Theme.night],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 36)

                    content

                    footer
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: isCompletedOutcome)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 96, height: 96)
                Circle()
                    .strokeBorder(accent.opacity(0.6), lineWidth: 2)
                    .frame(width: 96, height: 96)
                headerIcon
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accent)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        switch state {
        case .saving: ProgressView().tint(accent).controlSize(.large)
        case .saved(let outcome): Image(systemName: outcome.isCompleted ? "checkmark.seal.fill" : "hammer.fill")
        case .queued: Image(systemName: "icloud.and.arrow.up")
        case .dropped: Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var title: String {
        switch state {
        case .saving: return "Saving your workout…"
        case .saved(let outcome):
            if session.isBattle { return "Battle run saved" }
            return outcome.isCompleted ? "Workout complete" : "Partial workout"
        case .queued: return "Saved on this phone"
        case .dropped: return "Couldn't save"
        }
    }

    private var subtitle: String {
        switch state {
        case .saving:
            return "\(reps) \(session.exercise.unitName)"
        case .saved(let outcome):
            if outcome.isCompleted { return "\(outcome.reps) \(session.exercise.unitName) · target reached" }
            return "\(outcome.reps) \(session.exercise.unitName) · \(outcome.completionReps) needed for XP and your streak"
        case .queued:
            return "You're offline. Your \(reps) reps are safe and will sync automatically when you reconnect. Rewards are added once it syncs."
        case .dropped(let message):
            return message
        }
    }

    private var accent: Color {
        switch state {
        case .saving: Theme.progressCyan
        case .saved(let outcome): outcome.isCompleted ? Theme.progressCyan : Theme.amberSoft
        case .queued: Theme.amberSoft
        case .dropped: Color(hex: 0xFF6B6B)
        }
    }

    private var isCompletedOutcome: Bool {
        if case .saved(let outcome) = state { return outcome.isCompleted }
        return false
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if case .saved(let outcome) = state {
            VStack(spacing: 12) {
                rewardGrid(outcome)
                if let battle = outcome.battleSubmission {
                    battleCard(battle, reps: outcome.reps)
                }
                if !outcome.credits.isEmpty || outcome.overflowReps > 0 {
                    constructionCard(outcome)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
    }

    private func rewardGrid(_ outcome: WorkoutOutcomeDTO) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            rewardTile(value: "\(outcome.reps)", label: "Reps", color: Theme.progressCyan) {
                Image("stat_dumbbell").resizable().scaledToFit().frame(width: 28, height: 28)
            }
            rewardTile(value: "+\(outcome.coinsAwarded)", label: "Coins", color: Theme.gold) {
                Image("gold_coin_star").resizable().scaledToFit().frame(width: 26, height: 26)
            }
            rewardTile(value: "+\(outcome.xpAwarded)", label: "XP", color: Theme.progressCyan) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.progressCyan)
            }
            rewardTile(
                value: outcome.streakDayAwarded ? "+1" : "—",
                label: outcome.streakDayAwarded ? "Streak day" : "Streak",
                color: Theme.streakOrange
            ) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        .linearGradient(colors: [Theme.amberSoft, Color(hex: 0xFF6B1E)], startPoint: .top, endPoint: .bottom)
                    )
            }
        }
    }

    private func rewardTile<Icon: View>(value: String, label: String, color: Color, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 12) {
            icon().frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .battleCardStyle()
    }

    private func battleCard(_ submission: String, reps: Int) -> some View {
        let scored = submission == "scored"
        return HStack(spacing: 12) {
            CrossedSwordsIcon(color: scored ? Theme.amberSoft : Theme.mist)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(scored ? "Battle score: \(reps)" : "Too late for the battle")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Text(scored
                     ? "Your score is in. The result appears once your opponent submits or the deadline passes."
                     : "This run reached the server after the battle deadline, so it doesn't change the result. Your progress still counts.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .battleCardStyle()
    }

    private func constructionCard(_ outcome: WorkoutOutcomeDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONSTRUCTION")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.mist)

            ForEach(Array(outcome.credits.enumerated()), id: \.offset) { _, credit in
                HStack(spacing: 12) {
                    Image(systemName: credit.stageCompleted ? "checkmark.circle.fill" : "hammer.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(credit.stageCompleted ? Color(hex: 0x3DDC84) : Theme.amberSoft)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(credit.towerName) · Stage \(credit.stageNumber)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                        Text(credit.stageCompleted ? "\(credit.stageName) complete" : "\(credit.stageName) · +\(credit.reps) reps")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }
                    Spacer(minLength: 0)
                    Text("+\(credit.reps)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.progressCyan)
                }
            }

            if !outcome.isCompleted {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.progressCyan)
                    Text("Progress saved — your next session continues from here.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
                .padding(.top, 2)
            }

            ForEach(outcome.towersCompleted, id: \.towerId) { tower in
                HStack(spacing: 10) {
                    Image("stat_tower").resizable().scaledToFit().frame(width: 26, height: 26)
                    Text("\(tower.towerName) built!")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.top, 2)
            }

            if outcome.overflowReps > 0 {
                Text("Every tower is built. These \(outcome.overflowReps) reps still count toward your stats, coins and streak.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch state {
        case .saving:
            EmptyView()
        case .queued:
            VStack(spacing: 10) {
                GoldButton(title: "Try Again") {
                    Image(systemName: "arrow.clockwise").font(.system(size: 16, weight: .bold))
                } action: { onRetry() }
                secondaryButton("Done")
            }
        case .saved, .dropped:
            GoldButton(title: "Done") {
                Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
            } action: { onDone() }
        }
    }

    private func secondaryButton(_ title: String) -> some View {
        Button(action: onDone) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(PressScaleStyle())
    }
}
