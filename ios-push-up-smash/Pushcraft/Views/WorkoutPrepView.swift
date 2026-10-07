import SwiftUI

/// Session details for the upcoming workout. Start registers the workout with
/// the server first, so a workout can only begin online; progress and rewards
/// are applied only when the server accepts the finished workout.
struct WorkoutPrepView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var exercise: Exercise = .pushUps
    @State private var isStarting = false
    @State private var startError: String?
    @State private var activeSession: ActiveSession?

    private var data: HomeData { appState.progress.homeData }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A1730), Theme.night],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    backButton

                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR SESSION")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(Theme.mist)
                        Text(data.isAllComplete ? "Bonus workout" : "Stage \(data.stageNumber) of \(data.totalStages)")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.ivory)
                        Text(data.isAllComplete
                             ? "Every tower is built — reps still count toward your stats"
                             : "\(data.towerName) · \(data.stageName)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }
                    .padding(.top, 6)

                    exercisePicker

                    VStack(spacing: 0) {
                        detailRow(
                            icon: { Image(systemName: "dumbbell.fill") },
                            title: "\(data.sets) sets × \(data.repsPerSet) \(exercise.unitName)",
                            subtitle: "\(data.totalPlannedReps) reps completes the workout · keep going for more"
                        )
                        divider
                        detailRow(
                            icon: { Image(systemName: "sparkles") },
                            title: "+\(data.xpPerWorkout) XP & a streak day",
                            subtitle: "When you reach \(data.totalPlannedReps) reps"
                        )
                        divider
                        detailRow(
                            icon: { Image("stone_blocks_sparkle").resizable().scaledToFit() },
                            title: data.isAllComplete ? "Bonus reps" : "\(data.repsToGo) reps to finish \(data.stageName)",
                            subtitle: "Every valid rep builds your tower"
                        )
                        divider
                        detailRow(
                            icon: { Image(systemName: "iphone.gen3") },
                            title: "Prop the phone up",
                            subtitle: exercise == .sitUps
                                ? "Prop it up to your side so the camera sees your whole body"
                                : "Lean it against something so the front camera sees your full body"
                        )
                    }
                    .background(Theme.cardFill, in: .rect(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.pillBorder, lineWidth: 1)
                    }

                    if let startError {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.amberSoft)
                            Text(startError)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.ivory)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amber.opacity(0.1), in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.amberSoft.opacity(0.5), lineWidth: 1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    GoldButton(title: isStarting ? "Starting…" : "Start Workout", isLoading: isStarting) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .bold))
                    } action: {
                        start()
                    }

                    Text("Workouts need an internet connection to start. If you lose connection or the app closes mid-workout, your reps are kept on this phone and saved automatically.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(0.8))
                }
                .padding(16)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: startError)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeSession) { session in
            WorkoutFlowView(session: session)
                .environment(appState)
        }
    }

    private func start() {
        guard !isStarting else { return }
        isStarting = true
        startError = nil
        Task {
            defer { isStarting = false }
            do {
                activeSession = try await appState.workouts.start(
                    exercise: exercise,
                    battleID: nil,
                    rules: appState.progress.rules
                )
            } catch {
                startError = (error as? LocalizedError)?.errorDescription ?? WorkoutError.server.errorDescription
            }
        }
    }

    // MARK: - Exercise picker

    /// One exercise per session — either counts as reps toward any tower.
    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHOOSE YOUR EXERCISE")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.mist)

            HStack(spacing: 12) {
                exerciseOption(.pushUps, symbol: "figure.strengthtraining.functional")
                exerciseOption(.sitUps, symbol: "figure.core.strength")
            }

            Text("Either exercise earns reps toward any tower.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist.opacity(0.8))
        }
    }

    private func exerciseOption(_ option: Exercise, symbol: String) -> some View {
        let isSelected = exercise == option
        return Button {
            exercise = option
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: 0x3A2200) : Color(hex: 0xAFC3E8))
                Text(option.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color(hex: 0x3A2200) : Theme.ivory)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.cardFill)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? .clear : Theme.pillBorder, lineWidth: 1)
            }
            .shadow(color: isSelected ? Theme.amber.opacity(0.25) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(option.displayName) exercise")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

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

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 68)
    }

    private func detailRow<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 48, height: 48)
                .overlay {
                    icon()
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ivory.opacity(0.9))
                        .frame(width: 24, height: 24)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
