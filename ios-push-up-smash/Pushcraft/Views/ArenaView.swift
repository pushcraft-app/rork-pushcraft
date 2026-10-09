import SwiftUI
import UIKit

/// Live camera + skeleton, the floating block, counters and depth meter.
/// Runs one registered workout: checkpoints every rep to disk, shows the
/// "Completed" banner at the target, and for battles stops scoring at 60 s.
///
/// Battles open on a waiting screen. Once both phones meet on the battle's
/// live channel they run the same 5-second countdown, the run is registered
/// with the server at GO, and both 60-second clocks run from that moment.
struct ArenaView: View {
    let session: ActiveSession
    let workouts: WorkoutService
    var onEnd: (_ reps: Int, _ blocks: Int, _ reason: WorkoutEndReason) -> Void
    /// Leaves a battle before GO without using up the run.
    var onLeave: () -> Void = {}

    @Environment(AppState.self) private var appState

    @State private var engine: GameEngine
    @State private var remainingSeconds: Int
    @State private var hasEnded = false
    @State private var confirmEnd = false
    @State private var showProgressTip = false
    @State private var countdownRemaining: Int?
    @State private var showGo = false
    @State private var sound = SoundService()
    @State private var liveSync = BattleLiveSync()
    @State private var battleStage: BattleStage = .waiting
    @State private var isRegistered = false
    @State private var registrationError: String?
    @Environment(\.scenePhase) private var scenePhase

    private enum BattleStage {
        case waiting, countdown, live
    }

    init(
        session: ActiveSession,
        workouts: WorkoutService,
        onEnd: @escaping (Int, Int, WorkoutEndReason) -> Void,
        onLeave: @escaping () -> Void = {}
    ) {
        self.session = session
        self.workouts = workouts
        self.onEnd = onEnd
        self.onLeave = onLeave
        _engine = State(initialValue: GameEngine(exercise: session.exercise))
        _remainingSeconds = State(initialValue: session.battleDurationSeconds)
    }

    private var isComplete: Bool { engine.reps >= session.completionReps }

    var body: some View {
        ZStack {
            CameraPreviewView(displayLayer: engine.camera.displayLayer)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.62),
                    .init(color: .black.opacity(0.65), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            SkeletonView(pose: engine.pose)
                .ignoresSafeArea()
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    engine.layout.screenSize = size
                }

            hud

            EffectsOverlay(engine: engine)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if session.isBattle && battleStage == .waiting {
                BattleWaitingOverlay(
                    myName: appState.progress.displayName,
                    myAvatarPath: appState.progress.dashboard?.profile.avatarPath,
                    opponentName: battle?.opponentName,
                    opponentAvatarPath: battle?.opponentAvatarPath,
                    isConnected: liveSync.isConnected,
                    onLeave: leaveBeforeStart
                )
                .transition(.opacity)
            }

            if countdownRemaining != nil || showGo {
                StartCountdownOverlay(count: countdownRemaining, isGo: showGo)
                    .allowsHitTesting(false)
            }

            if session.isBattle && battleStage == .countdown {
                VStack {
                    Spacer()
                    Button(action: leaveBeforeStart) {
                        Text("Leave")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .frame(height: 44)
                            .background(Theme.panel, in: .capsule)
                            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                    }
                    .buttonStyle(PressScaleStyle())
                    .padding(.bottom, 40)
                }
            }

            if let message = cameraMessage {
                CameraMessageView(message: message)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            engine.onRep = { [weak engine] in
                guard let engine else { return }
                workouts.checkpoint(id: session.id, reps: engine.reps, blocks: engine.smashCount)
                liveSync.update(reps: engine.reps)
            }
            if let battleID = session.battleID {
                liveSync.connect(
                    battleID: battleID,
                    isHost: battle?.isHost ?? false,
                    battleDuration: session.battleDurationSeconds
                )
                // Opponent already played their run: nobody to wait for.
                if battle?.opponentSubmitted == true {
                    liveSync.beginSolo()
                }
            }
            // Reps only count after GO. The camera warms up and calibrates
            // during the countdown (and the battle waiting screen).
            engine.isAcceptingReps = false
            engine.start()
            showFirstSessionTipIfNeeded()
        }
        .onDisappear {
            checkpoint()
            liveSync.disconnect()
            engine.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: if !hasEnded { engine.start() }
            case .inactive, .background:
                checkpoint()
                if phase == .background { engine.stop() }
            @unknown default: break
            }
        }
        .task { await heartbeat() }
        .task { await runBattleTimer() }
        .task { await runCountdown() }
        .alert(
            "Couldn't start your run",
            isPresented: Binding(get: { registrationError != nil }, set: { _ in })
        ) {
            Button("OK", role: .cancel) {
                registrationError = nil
                hasEnded = true
                engine.stop()
                onLeave()
            }
        } message: {
            Text(registrationError ?? "")
        }
        .onChange(of: isComplete) { _, complete in
            if complete && !session.isBattle {
                HapticService().smash()
            }
        }
        .confirmationDialog(endDialogTitle, isPresented: $confirmEnd, titleVisibility: .visible) {
            Button(engine.reps == 0 && !session.isBattle ? "Leave Workout" : "End & Save", role: .destructive) {
                end(.finished)
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text(endDialogMessage)
        }
    }

    // MARK: - Timing

    /// 5-4-3-2-1 get-ready countdown before a regular workout starts counting.
    /// Battles skip it (their 60-second clock is server-side and already
    /// running), and an early exit cancels it.
    private func runCountdown() async {
        guard !session.isBattle else { return }
        try? await Task.sleep(for: .seconds(0.6))
        for tick in stride(from: 5, through: 1, by: -1) {
            guard !hasEnded else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                countdownRemaining = tick
            }
            sound.play(.drop, pitch: 1.5, volume: 0.8)
            HapticService.ui.tick()
            try? await Task.sleep(for: .seconds(1))
        }
        guard !hasEnded else { return }
        countdownRemaining = nil
        engine.isAcceptingReps = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showGo = true }
        sound.play(.hit, pitch: 1.25, volume: 1)
        HapticService.ui.success()
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeOut(duration: 0.3)) { showGo = false }
    }

    private func heartbeat() async {
        while !Task.isCancelled && !hasEnded {
            try? await Task.sleep(for: .seconds(4))
            checkpoint()
        }
    }

    /// Drives a battle from the shared start moment: waiting → 5-4-3-2-1 →
    /// GO (registers the run) → exactly the battle duration → end. Both
    /// phones derive every step from the same anchor, so they stay in step.
    private func runBattleTimer() async {
        guard session.isBattle else { return }
        let countdown = BattleLiveSync.countdownSeconds
        let duration = Double(session.battleDurationSeconds)
        var lastTick: Int?

        while !Task.isCancelled && !hasEnded {
            guard let anchor = liveSync.startAnchor else {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            let elapsed = Date().timeIntervalSince(anchor)

            if elapsed < countdown {
                if battleStage == .waiting {
                    withAnimation(.easeOut(duration: 0.25)) { battleStage = .countdown }
                }
                let tick = Int((countdown - elapsed).rounded(.up))
                if tick != lastTick {
                    lastTick = tick
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { countdownRemaining = tick }
                    sound.play(.drop, pitch: 1.5, volume: 0.8)
                    HapticService.ui.tick()
                }
            } else {
                if battleStage != .live {
                    battleStage = .live
                    countdownRemaining = nil
                    engine.isAcceptingReps = true
                    liveSync.update(reps: engine.reps)
                    Task { await registerRun() }
                    if elapsed < countdown + 1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showGo = true }
                        sound.play(.hit, pitch: 1.25, volume: 1)
                        HapticService.ui.success()
                        Task {
                            try? await Task.sleep(for: .seconds(0.8))
                            withAnimation(.easeOut(duration: 0.3)) { showGo = false }
                        }
                    }
                }
                let remaining = max(0, duration - (elapsed - countdown))
                remainingSeconds = Int(remaining.rounded(.up))
                if remaining <= 0 {
                    engine.isAcceptingReps = false
                    // The score can only be saved once the run is registered.
                    if isRegistered {
                        end(.timer)
                        return
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Registers the battle run at GO. Network hiccups retry every 2 seconds
    /// (reusing the same session ID); a definitive refusal leaves the arena.
    private func registerRun() async {
        while !hasEnded && !isRegistered {
            do {
                _ = try await workouts.register(session)
                isRegistered = true
                checkpoint()
                print("[Arena] Battle run registered at GO")
            } catch let error as WorkoutError where error != .offline && error != .server {
                engine.isAcceptingReps = false
                registrationError = error.errorDescription
                return
            } catch {
                print("[Arena] Registering battle run failed, retrying: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Leaves a battle before GO. Nothing was registered, so the run is kept.
    private func leaveBeforeStart() {
        guard !hasEnded, battleStage != .live else { return }
        HapticService.ui.tap()
        hasEnded = true
        engine.isAcceptingReps = false
        engine.stop()
        liveSync.disconnect()
        onLeave()
    }

    private func checkpoint() {
        guard !hasEnded, !session.isBattle || isRegistered else { return }
        workouts.checkpoint(id: session.id, reps: engine.reps, blocks: engine.smashCount)
    }

    private func end(_ reason: WorkoutEndReason) {
        guard !hasEnded else { return }
        if !session.isBattle {
            AppPreferences.shared.hasSeenProgressTip = true
        }
        engine.isAcceptingReps = false
        checkpoint()
        hasEnded = true
        engine.stop()
        onEnd(engine.reps, engine.smashCount, reason)
    }

    private var endDialogTitle: String {
        if session.isBattle { return "End your battle run?" }
        return engine.reps == 0 ? "Leave this workout?" : "End workout?"
    }

    private var endDialogMessage: String {
        if session.isBattle {
            return "You only get one run. Your score will be \(engine.reps) \(session.exercise.unitName)."
        }
        if engine.reps == 0 {
            return "No reps yet, so nothing will be saved."
        }
        if isComplete {
            return "Your \(engine.reps) reps will be saved to your tower."
        }
        return "Your \(engine.reps) reps are already saved — your tower keeps every one, and your next session continues from there. Reach \(session.completionReps) for XP and a streak day."
    }

    // MARK: - HUD

    /// One-time reassurance in the first real session: reps save as they go.
    private func showFirstSessionTipIfNeeded() {
        guard !session.isBattle, !AppPreferences.shared.hasSeenProgressTip else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.8)) {
            showProgressTip = true
        }
        Task {
            try? await Task.sleep(for: .seconds(7))
            withAnimation { showProgressTip = false }
            AppPreferences.shared.hasSeenProgressTip = true
        }
    }

    private var progressTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.progressCyan)
            Text("Every rep saves as you go — stop anytime.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.progressCyan.opacity(0.45), lineWidth: 1) }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }

    private var hud: some View {
        VStack(spacing: 0) {
            if !session.isBattle {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }

            if showProgressTip {
                progressTip
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if session.isBattle {
                VersusHeader(
                    myReps: engine.reps,
                    opponentReps: liveSync.opponentReps,
                    myName: appState.progress.displayName,
                    myAvatarPath: appState.progress.dashboard?.profile.avatarPath,
                    opponentName: battle?.opponentName,
                    opponentAvatarPath: battle?.opponentAvatarPath,
                    remainingSeconds: remainingSeconds
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)
            } else {
                HStack(alignment: .top) {
                    StatCard(value: engine.reps, label: "REPS", tint: Theme.cyan) {
                        Image(systemName: "figure.strengthtraining.functional")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Theme.cyan)
                            .shadow(color: Theme.cyan, radius: 4)
                    }
                    Spacer(minLength: 12)
                    StatCard(value: engine.displayedCoins, label: "COINS", tint: Theme.gold) {
                        Image("gold_coin_star")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .shadow(color: Theme.gold.opacity(0.8), radius: 6)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                engine.layout.coinTarget = CGPoint(x: frame.midX, y: frame.midY)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            blockStage
                .padding(.top, 14)

            Spacer(minLength: 12)

            // Tighter grouping that hugs the bottom edge so the block and
            // body stay unobstructed.
            VStack(spacing: 6) {
                DepthMeter(tracking: engine.tracking)
                    .padding(.horizontal, 40)
                CueView(cue: engine.cue, exercise: engine.exercise)
            }
            .padding(.bottom, 10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showProgressTip)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !session.isBattle {
                Button {
                    if engine.reps == 0 {
                        end(.finished)
                    } else {
                        confirmEnd = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                        Text("Done")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Theme.panel, in: .capsule)
                    .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Done with workout")
            }

            Spacer(minLength: 8)

            targetPill
        }
    }

    private var targetPill: some View {
        HStack(spacing: 7) {
            Image(systemName: isComplete ? "checkmark.seal.fill" : "target")
                .font(.system(size: 14, weight: .bold))
            Text(isComplete ? "COMPLETED · KEEP GOING" : "\(engine.reps) / \(session.completionReps)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(isComplete ? 1 : 0)
                .contentTransition(.numericText())
        }
        .foregroundStyle(isComplete ? Color(hex: 0x062330) : .white)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background {
            if isComplete {
                Capsule().fill(
                    .linearGradient(colors: [Color(hex: 0x7BE9FF), Theme.progressCyan], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Theme.progressCyan.opacity(0.7), radius: 10)
            } else {
                Capsule().fill(Theme.panel)
            }
        }
        .overlay { Capsule().strokeBorder(.white.opacity(isComplete ? 0 : 0.22), lineWidth: 1) }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isComplete)
        .accessibilityLabel(isComplete ? "Workout completed. Keep going." : "\(engine.reps) of \(session.completionReps) reps")
    }

    private var blockStage: some View {
        let isCharging = engine.tracking.phase == .charging || engine.tracking.phase == .charged
        let charge = isCharging ? engine.tracking.depth : 0
        let damage = engine.spec.health > 0 ? Double(engine.hitsTaken) / Double(engine.spec.health) : 0

        return VStack(spacing: 14) {
            ZStack {
                BlockView(
                    tier: engine.spec.tier,
                    seed: engine.blockSeed,
                    damage: damage,
                    charge: charge,
                    isCharged: engine.tracking.phase == .charged,
                    hitTrigger: engine.hitCount
                )
                .modifier(BlockEntrance(phase: engine.blockPhase))
                .id(engine.blockID)
                .transition(.identity)

                if let payout = engine.payout {
                    PayoutText(amount: payout.amount)
                        .id(payout.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: 128, height: 128)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                engine.layout.blockFrame = frame
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: engine.payout?.id)

            HealthPips(total: engine.spec.health, remaining: engine.health)
                .opacity(engine.blockPhase == .shattered ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: engine.blockPhase)

            Text("\(engine.spec.tier.name)  ·  LV \(engine.spec.level + 1)  ·  +\(engine.spec.payout)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(engine.spec.tier.accent)
                .shadow(color: .black.opacity(0.7), radius: 3)
                .contentTransition(.numericText())
                .animation(.snappy, value: engine.spec.level)
        }
    }

    private var cameraMessage: CameraMessage? {
        switch engine.cameraStatus {
        case .denied: .denied
        case .noCamera: .noCamera
        case .failed: .failed
        case .idle, .running: nil
        }
    }

    private var battle: Battle? {
        session.battleID.flatMap { appState.battles.battle(withID: $0) }
    }
}

// MARK: - Block entrance / shatter

private struct BlockEntrance: ViewModifier {
    let phase: BlockPhase
    @State private var hasLanded = false

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .scaleEffect(scale)
            .opacity(phase == .shattered ? 0 : (hasLanded || phase != .dropping ? 1 : 0))
            .rotationEffect(.degrees(phase == .dropping && !hasLanded ? -8 : 0))
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                    hasLanded = true
                }
            }
            .animation(.easeOut(duration: 0.14), value: phase)
    }

    private var offsetY: CGFloat {
        hasLanded ? 0 : -260
    }

    private var scale: CGFloat {
        phase == .shattered ? 1.35 : 1
    }
}

private struct PayoutText: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image("gold_coin_star")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
            Text("+\(amount)")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom)
                )
        }
        .shadow(color: Theme.gold.opacity(0.9), radius: 12)
        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 3)
        .allowsHitTesting(false)
    }
}

// MARK: - Battle versus HUD

/// Battle-only header: both players' photos ringed in their color (blue = you,
/// red = opponent) with names underneath, the match clock in the middle, and a
/// tug-of-war gauge flanked by each side's live rep count.
private struct VersusHeader: View {
    let myReps: Int
    let opponentReps: Int
    let myName: String
    let myAvatarPath: String?
    let opponentName: String?
    let opponentAvatarPath: String?
    let remainingSeconds: Int

    private static let myColor = Theme.cyan
    private static let opponentColor = Color(hex: 0xFF5A5A)
    private static let lowColor = Color(hex: 0xFF5A5A)

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                player(name: myName, avatarPath: myAvatarPath, ring: Self.myColor)
                Spacer(minLength: 4)
                clock
                    .padding(.top, 14)
                Spacer(minLength: 4)
                player(name: opponentName ?? "Opponent", avatarPath: opponentAvatarPath, ring: Self.opponentColor)
            }

            HStack(spacing: 10) {
                repCount(myReps, color: Self.myColor)
                    .frame(minWidth: 34, alignment: .leading)
                gauge
                repCount(opponentReps, color: Self.opponentColor)
                    .frame(minWidth: 34, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.panel, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private var clock: some View {
        let isLow = remainingSeconds <= 10
        return Text(String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60))
            .font(.system(size: 34, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isLow ? Self.lowColor : .white)
            .shadow(color: (isLow ? Self.lowColor : .black).opacity(0.6), radius: isLow ? 8 : 3)
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: remainingSeconds)
            .accessibilityLabel("\(remainingSeconds) seconds left")
    }

    private func player(name: String, avatarPath: String?, ring: Color) -> some View {
        VStack(spacing: 6) {
            VersusAvatar(name: name, avatarPath: avatarPath, ring: ring)
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 92)
    }

    private func repCount(_ reps: Int, color: Color) -> some View {
        Text("\(reps)")
            .font(.system(size: 24, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .shadow(color: color.opacity(0.8), radius: 6)
            .contentTransition(.numericText())
            .animation(.snappy, value: reps)
    }

    /// One capsule, blue filling from the left and red from the right. While
    /// nobody has scored it sits exactly centered.
    private var gauge: some View {
        let total = myReps + opponentReps
        let share: CGFloat = total == 0 ? 0.5 : CGFloat(myReps) / CGFloat(total)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        .linearGradient(
                            colors: [Self.opponentColor, Self.opponentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Self.opponentColor.opacity(0.6), radius: 5)

                Capsule()
                    .fill(
                        .linearGradient(
                            colors: [Self.myColor.opacity(0.7), Self.myColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * share, proxy.size.height))
                    .shadow(color: Self.myColor.opacity(0.7), radius: 5)
            }
        }
        .frame(height: 12)
        .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1) }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: share)
        .accessibilityLabel("Push-up gauge")
        .accessibilityValue("You \(myReps), opponent \(opponentReps)")
    }
}

/// Circular player photo with the player's colored ring on top.
private struct VersusAvatar: View {
    let name: String?
    let avatarPath: String?
    let ring: Color
    var size: CGFloat = 64

    var body: some View {
        BattleAvatar(name: name, avatarPath: avatarPath, size: size)
            .overlay {
                Circle()
                    .strokeBorder(ring, lineWidth: 3)
                    .shadow(color: ring.opacity(0.8), radius: 6)
            }
    }
}

/// Shown before a battle starts: both players, a pulsing "waiting" line and a
/// Leave button. The camera keeps warming up behind it.
private struct BattleWaitingOverlay: View {
    let myName: String
    let myAvatarPath: String?
    let opponentName: String?
    let opponentAvatarPath: String?
    let isConnected: Bool
    var onLeave: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                HStack(spacing: 22) {
                    side(name: myName, avatarPath: myAvatarPath, ring: Theme.cyan, dimmed: false)
                    Text("VS")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                    side(name: opponentName ?? "Opponent", avatarPath: opponentAvatarPath, ring: Color(hex: 0xFF5A5A), dimmed: true)
                }

                VStack(spacing: 8) {
                    Text("Waiting for \(opponentName ?? "your friend")…")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(isConnected
                         ? "The battle starts with a 5-second countdown as soon as they open it."
                         : "Connecting to the battle…")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color(hex: 0x3DDC84) : Theme.amberSoft)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 1 : 0.3)
                    Text(isConnected ? "Live" : "Connecting")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.panel, in: .capsule)

                Spacer()

                Button(action: onLeave) {
                    Text("Leave")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                }
                .buttonStyle(PressScaleStyle())
                .padding(.horizontal, 32)

                Text("Leaving now doesn't use up your run.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func side(name: String, avatarPath: String?, ring: Color, dimmed: Bool) -> some View {
        VStack(spacing: 8) {
            VersusAvatar(name: name, avatarPath: avatarPath, ring: ring, size: 84)
                .opacity(dimmed ? (pulse ? 0.95 : 0.55) : 1)
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 104)
        }
    }
}

// MARK: - Camera states

private enum CameraMessage {
    case denied, noCamera, failed

    var symbol: String {
        switch self {
        case .denied: "video.slash.fill"
        case .noCamera: "camera.metering.unknown"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var title: String {
        switch self {
        case .denied: "Camera access needed"
        case .noCamera: "No camera found"
        case .failed: "Camera couldn't start"
        }
    }

    var body: String {
        switch self {
        case .denied: "Your reps control the game through the camera. Allow camera access in Settings to start smashing."
        case .noCamera: "This device doesn't have a camera available right now."
        case .failed: "Something went wrong starting the camera. Close and reopen the app to try again."
        }
    }
}

private struct CameraMessageView: View {
    let message: CameraMessage
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: message.symbol)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.cyan)
            Text(message.title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(message.body)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            if message == .denied {
                Button {
                    HapticService.ui.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 48)
                        .background(Theme.cyan, in: .capsule)
                }
                .padding(.top, 4)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.cyan.opacity(0.6), lineWidth: 1.5)
        }
        .padding(.horizontal, 28)
    }
}

/// Big 5-4-3-2-1 get-ready overlay shown before reps start counting.
private struct StartCountdownOverlay: View {
    let count: Int?
    let isGo: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if isGo {
                    Text("GO!")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Theme.progressCyan], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Theme.progressCyan.opacity(0.8), radius: 18)
                } else if let count {
                    Text("\(count)")
                        .font(.system(size: 110, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 12)
                        .id(count)
                        .transition(.scale(scale: 1.7).combined(with: .opacity))
                }

                if !isGo {
                    Text("GET INTO POSITION")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.6), radius: 4)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
        }
    }
}
