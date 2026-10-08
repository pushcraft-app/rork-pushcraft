import SwiftUI
import UIKit

/// The Battles tab: create or join battles via codes, track active battles,
/// and review finished results. Backed by the server's battle functions.
struct BattlesView: View {
    private enum Segment: String, CaseIterable {
        case join, active, completed

        var title: String { rawValue.capitalized }
    }

    @Environment(AppState.self) private var appState
    @State private var segment: Segment = .join
    @State private var path = NavigationPath()

    // Join tab state
    @State private var joinCode = ""
    @State private var isJoining = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var battleExercise: Exercise = .pushUps

    // Shared state
    @State private var showCopiedToast = false
    @State private var shareItem: ShareItem?
    @State private var toastTask: Task<Void, Never>?

    private let haptic = HapticService()

    private var store: BattleStore { appState.battles }
    private var home: HomeData { appState.progress.homeData }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    segmentedControl
                        .padding(.top, 18)

                    switch segment {
                    case .join: joinContent
                    case .active: activeContent
                    case .completed: completedContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await appState.refresh() }
            .background(Theme.towersNavy.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BattleRoute.self) { route in
                navigationDestination(for: route)
            }
            .sheet(item: $shareItem) { item in
                ActivityShareSheet(items: [item.message])
            }
            .overlay(alignment: .top) { copiedToast }
            .alert(
                "Battles",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                if !store.hasLoaded { try? await store.load() }
                if let invitation = store.invitation { battleExercise = invitation.exercise }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            CountersRow(streak: home.streak, xp: home.xp, coinsDisplay: home.coinsDisplay)

            Text("Battles")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .padding(.top, 14)

            Text("Challenge a friend. Share a code and battle together.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(.join)
            segmentDivider
            segmentButton(.active)
            segmentDivider
            segmentButton(.completed)
        }
        .background(Color(hex: 0x101D35), in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(hex: 0x27395C), lineWidth: 1)
        }
    }

    private func segmentButton(_ seg: Segment) -> some View {
        let isSelected = segment == seg
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { segment = seg }
            haptic.tap()
        } label: {
            Text(seg.title)
                .font(.system(size: 17, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color(hex: 0x3A2200) : Theme.mist)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom))
                            .shadow(color: Theme.amberDeep.opacity(0.35), radius: 8, y: 3)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var segmentDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 22)
    }

    // MARK: - Join tab

    private var joinContent: some View {
        VStack(spacing: 16) {
            createBattleCard
            joinWithCodeCard
        }
        .padding(.top, 16)
    }

    private var createBattleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CrossedSwordsIcon(color: Color(hex: 0xAFC3E8))
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Battle")
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ivory)
                    Text("Create a challenge and invite a friend.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
                Spacer(minLength: 0)
            }

            exercisePicker

            if let invitation = store.invitation {
                codeRow(invitation)
            }

            GoldButton(title: store.invitation == nil ? "Create & Share Code" : "Share Code", isLoading: isCreating) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .bold))
            } action: {
                createAndShare()
            }

            Text("Invites expire after 24 hours. Once a friend joins, you both have 24 hours for your one 60-second run.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
    }

    /// Hosts pick the single exercise both players perform — raw rep counts
    /// only compare fairly within the same movement.
    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXERCISE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.mist)

            HStack(spacing: 8) {
                exerciseChip(.pushUps)
                exerciseChip(.sitUps)
            }
        }
    }

    private func exerciseChip(_ option: Exercise) -> some View {
        let isSelected = battleExercise == option
        return Button {
            battleExercise = option
            haptic.tap()
        } label: {
            Text(option.displayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color(hex: 0x3A2200) : Theme.mist)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(isSelected ? 0 : 0.14), lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(option.displayName) battle exercise")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func codeRow(_ invitation: Battle) -> some View {
        HStack(spacing: 12) {
            Text("BATTLE CODE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.mist)

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1, height: 22)

            Text(invitation.code)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.ivory)

            Spacer(minLength: 8)

            Button {
                copyCode(invitation.code)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xAFC3E8))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Copy battle code")
        }
        .padding(.leading, 14)
        .frame(height: 54)
        .recessedFieldStyle()
    }

    private var joinWithCodeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: 0xAFC3E8))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Join with Code")
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ivory)
                    Text("Enter your friend's code to join the battle.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
                Spacer(minLength: 0)
            }

            TextField("Enter battle code", text: $joinCode)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.ivory)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .recessedFieldStyle()
                .onChange(of: joinCode) { _, newValue in
                    let filtered = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    if filtered != newValue { joinCode = filtered }
                }

            GoldButton(title: "Fight", isLoading: isJoining) {
                CrossedSwordsIcon(color: Color(hex: 0x3A2200))
                    .frame(width: 22, height: 22)
            } action: {
                fight()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
    }

    // MARK: - Active tab

    private var activeContent: some View {
        VStack(spacing: 12) {
            if store.activeBattles.isEmpty {
                emptyState(
                    icon: { CrossedSwordsIcon(color: Theme.mist).frame(width: 30, height: 30) },
                    title: "No active battles yet.",
                    message: "Create a battle or join a friend using their code."
                )
            } else {
                ForEach(store.activeBattles) { battle in
                    activeBattleCard(battle)
                }
            }
        }
        .padding(.top, 16)
    }

    private func activeBattleCard(_ battle: Battle) -> some View {
        Button {
            path.append(BattleRoute.details(battle.id))
        } label: {
            HStack(spacing: 12) {
                BattleAvatar(name: battle.opponentName, avatarPath: battle.opponentAvatarPath)

                VStack(alignment: .leading, spacing: 3) {
                    Text(battle.opponentName ?? "Waiting for opponent")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    Text(battle.exercise.challengeTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(battle.statusText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(battle.phase == .waiting ? Theme.amberSoft : Theme.progressCyan)
                        if let deadline = battle.phase == .waiting ? battle.inviteExpiresAt : battle.deadlineAt {
                            Text("· \(deadline, style: .relative) left")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.mist.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)

                Text(battle.canStartRun ? "Play" : "View")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(battle.canStartRun ? Color(hex: 0x3A2200) : Theme.ivory)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background {
                        if battle.canStartRun {
                            Capsule().fill(.linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom))
                        } else {
                            Capsule().fill(Color.white.opacity(0.08))
                        }
                    }
                    .overlay { Capsule().strokeBorder(.white.opacity(battle.canStartRun ? 0 : 0.16), lineWidth: 1) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .battleCardStyle()
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - Completed tab

    private var completedContent: some View {
        VStack(spacing: 12) {
            if store.completedBattles.isEmpty {
                emptyState(
                    icon: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    },
                    title: "No completed battles yet.",
                    message: "Finish your first battle to see your results here."
                )
            } else {
                ForEach(store.completedBattles) { battle in
                    completedBattleCard(battle)
                }
            }
        }
        .padding(.top, 16)
    }

    private func completedBattleCard(_ battle: Battle) -> some View {
        Button {
            path.append(BattleRoute.result(battle.id))
        } label: {
            HStack(spacing: 12) {
                BattleAvatar(name: battle.opponentName, avatarPath: battle.opponentAvatarPath)

                VStack(alignment: .leading, spacing: 3) {
                    Text(battle.opponentName ?? "No opponent")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    if let result = battle.result {
                        Text("You \(scoreText(result.myScore)) · \(battle.opponentName ?? "Opponent") \(scoreText(result.opponentScore))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.mist)
                            .lineLimit(1)
                        Text(result.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist.opacity(0.7))
                    }
                }
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    if let result = battle.result {
                        Text(result.outcome.title.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(result.outcome.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(result.outcome.color.opacity(0.14), in: .capsule)
                    }
                    HStack(spacing: 3) {
                        Text("View Result")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.mist)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .battleCardStyle()
        }
        .buttonStyle(PressScaleStyle())
    }

    private func scoreText(_ score: Int?) -> String {
        score.map(String.init) ?? "—"
    }

    // MARK: - Empty state

    private func emptyState<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 8) {
            icon()
                .padding(.bottom, 4)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ivory)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)

            GoldButton(title: "Join a Battle") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { segment = .join }
                haptic.tap()
            }
            .padding(.top, 12)
        }
        .padding(20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .battleCardStyle()
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func navigationDestination(for route: BattleRoute) -> some View {
        switch route {
        case .details(let id):
            BattleDetailsView(battleID: id) { battle in
                share(battle)
            } onResult: {
                var resultPath = NavigationPath()
                resultPath.append(BattleRoute.result(id))
                path = resultPath
            }
        case .result(let id):
            BattleResultView(battleID: id) {
                path = NavigationPath()
                withAnimation { segment = .completed }
            }
        }
    }

    // MARK: - Actions

    private func createAndShare() {
        guard !isCreating else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let battle = try await store.createInvitation(exercise: battleExercise)
                share(battle)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    private func share(_ battle: Battle) {
        shareItem = ShareItem(message: "Challenge me on PushcraftPushUpFitnessGame — \(battle.exercise.challengeTitle)! Enter my battle code: \(battle.code).")
    }

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        haptic.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCopiedToast = true }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showCopiedToast = false }
        }
    }

    private func fight() {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Enter a battle code."
            return
        }
        guard code.count == 6, code.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            errorMessage = "Battle codes must be 6 letters or numbers."
            return
        }
        guard store.invitation?.code != code else {
            errorMessage = BattleError.ownBattle.errorDescription
            return
        }

        isJoining = true
        Task {
            defer { isJoining = false }
            do {
                let battle = try await store.join(code: code)
                joinCode = ""
                haptic.smash()
                path.append(BattleRoute.details(battle.id))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
        Group {
            if showCopiedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x3DDC84))
                    Text("Code copied.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ivory)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: 0x1A2A4A), in: .capsule)
                .overlay { Capsule().strokeBorder(Theme.amberSoft.opacity(0.5), lineWidth: 1) }
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

/// A share-sheet payload.
struct ShareItem: Identifiable {
    let id = UUID()
    let message: String
}

/// UIKit share sheet wrapper for battle invitations.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    BattlesView()
        .environment(AppState())
}
