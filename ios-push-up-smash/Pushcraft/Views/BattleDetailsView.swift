import SwiftUI

/// Battle Details: opponent, challenge rules, deadline and both players'
/// status, with the action for the battle's current phase. "Start Battle"
/// registers the player's single run online, then opens the camera arena.
struct BattleDetailsView: View {
    let battleID: UUID
    var onShare: (Battle) -> Void
    var onResult: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isStarting = false
    @State private var isCancelling = false
    @State private var errorMessage: String?
    @State private var activeSession: ActiveSession?
    @State private var confirmCancel = false

    private var battle: Battle? { appState.battles.battle(withID: battleID) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A1730), Theme.night], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    backButton

                    if let battle {
                        opponentHeader(battle)
                        challengeCard(battle)
                        statusCard(battle)
                        actionSection(battle)
                    } else {
                        Text("This battle is no longer available.")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.mist)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .refreshable { try? await appState.battles.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .task { try? await appState.battles.load() }
        .onChange(of: battle?.phase) { _, phase in
            if phase == .completed && activeSession == nil { onResult() }
        }
        .fullScreenCover(item: $activeSession, onDismiss: {
            Task {
                try? await appState.battles.load()
                if battle?.phase == .completed { onResult() }
            }
        }) { session in
            WorkoutFlowView(session: session)
                .environment(appState)
        }
        .alert(
            "Battle",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Cancel this invitation?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Invitation", role: .destructive) { cancelInvitation() }
            Button("Keep It", role: .cancel) {}
        } message: {
            Text("The code stops working and nobody can join.")
        }
    }

    // MARK: - Sections

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                Text("Back")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Theme.ivory)
        }
        .buttonStyle(PressScaleStyle())
    }

    private func opponentHeader(_ battle: Battle) -> some View {
        HStack(spacing: 14) {
            BattleAvatar(name: battle.opponentName, avatarPath: battle.opponentAvatarPath, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("BATTLE · \(battle.code)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.mist)
                Text(battle.opponentName ?? "Waiting for opponent")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                Text(battle.statusText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(battle.phase == .waiting ? Theme.amberSoft : Theme.progressCyan)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private func challengeCard(_ battle: Battle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CrossedSwordsIcon(color: Color(hex: 0xAFC3E8))
                    .frame(width: 26, height: 26)
                Text(battle.exercise.challengeTitle)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Spacer(minLength: 0)
            }
            Text(battle.exercise.challengeDescription)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
            Text("Both players perform \(battle.exercise.unitName). One run each, camera counted. Reach 30 reps to also earn XP and a streak day.")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.progressCyan)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
    }

    private func statusCard(_ battle: Battle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STATUS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.mist)
                Spacer()
                if let deadline = battle.phase == .waiting ? battle.inviteExpiresAt : battle.deadlineAt, deadline > Date() {
                    Label {
                        Text("\(deadline, style: .relative) left")
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.amberSoft)
                }
            }

            statusRow(
                label: "You",
                value: battle.mySubmitted
                    ? "\(battle.myScore ?? 0) \(battle.exercise.unitName)"
                    : (battle.myRunStarted ? "Run in progress" : "Not played yet"),
                done: battle.mySubmitted
            )
            statusRow(
                label: battle.opponentName ?? "Opponent",
                value: battle.opponentName == nil ? "Not joined" : (battle.opponentSubmitted ? "Submitted · hidden until the end" : "Not played yet"),
                done: battle.opponentSubmitted
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
    }

    private func statusRow(label: String, value: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(done ? Color(hex: 0x3DDC84) : Theme.mist.opacity(0.7))
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func actionSection(_ battle: Battle) -> some View {
        switch battle.phase {
        case .active:
            if battle.canStartRun {
                VStack(alignment: .leading, spacing: 10) {
                    GoldButton(title: battle.myRunStarted ? "Resume Battle" : "Start Battle", isLoading: isStarting) {
                        CrossedSwordsIcon(color: Color(hex: 0x3A2200))
                            .frame(width: 22, height: 22)
                    } action: {
                        startRun(battle)
                    }
                    Text("You get one 60-second run. Starting needs an internet connection; once started, your reps are kept even if the connection drops.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(0.8))
                }
            } else if battle.myRunStarted && !battle.mySubmitted {
                Text("Your run is saved on this phone and will sync automatically.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
        case .waiting:
            VStack(spacing: 10) {
                GoldButton(title: "Share Code") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                } action: {
                    onShare(battle)
                }
                if battle.isHost {
                    Button {
                        confirmCancel = true
                    } label: {
                        Text(isCancelling ? "Cancelling…" : "Cancel Invitation")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFF8A8A))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(isCancelling)
                }
            }
        case .completed:
            GoldButton(title: "View Result") {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .bold))
            } action: {
                onResult()
            }
        }
    }

    // MARK: - Actions

    private func startRun(_ battle: Battle) {
        guard !isStarting else { return }
        // A run already in progress on this phone resumes via sync rather than a second run.
        if let pending = appState.workouts.pendingRun(forBattle: battle.id), pending.state != .registering {
            Task { await appState.workouts.syncPending(); try? await appState.battles.load() }
            errorMessage = "Your run for this battle is already saved and is syncing."
            return
        }
        // The run is only registered with the server at GO, after both
        // players have met in the arena, so opening it here is free.
        do {
            activeSession = try appState.workouts.prepare(
                exercise: battle.exercise,
                battleID: battle.id,
                rules: appState.progress.rules
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func cancelInvitation() {
        isCancelling = true
        Task {
            defer { isCancelling = false }
            do {
                try await appState.battles.cancel(id: battleID)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }
}
