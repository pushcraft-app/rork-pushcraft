import AVFoundation
import Observation
import QuartzCore
import SwiftUI
import UIKit

/// Screen geometry the engine needs for effect choreography (all in global coordinates).
struct ArenaLayout: Equatable {
    var screenSize: CGSize = .zero
    var blockFrame: CGRect = .zero
    var coinTarget: CGPoint = .zero
}

enum CameraStatus: Equatable {
    case idle, running, denied, noCamera, failed
}

enum BlockPhase: Equatable {
    case dropping, idle, shattered
}

/// Streak drawn from the user's head up into the block on each hit.
struct HitBeam: Identifiable {
    static let lifetime = 0.32
    let id: Int
    let start: Double
    let from: CGPoint
    let to: CGPoint
    let color: Color
}

/// Owns the whole game: camera + pose → reps → block damage → payouts.
@Observable
final class GameEngine {
    static let coinsPerBurst = 14

    private(set) var cameraStatus: CameraStatus = .idle
    private(set) var reps = 0
    private(set) var coins = 0
    private(set) var displayedCoins = 0
    private(set) var spec = BlockSpec.make(level: 0)
    private(set) var health = BlockSpec.make(level: 0).health
    private(set) var blockID = 0
    private(set) var blockSeed: UInt64 = 7
    private(set) var blockPhase: BlockPhase = .dropping
    private(set) var hitCount = 0
    private(set) var smashCount = 0
    private(set) var tracking = RepTracking.initial
    private(set) var cue: CoachCue = .getInFrame
    private(set) var pose = DisplayPose.empty
    private(set) var coinBursts: [CoinBurst] = []
    private(set) var shardBursts: [ShardBurst] = []
    private(set) var rings: [ShockRing] = []
    private(set) var beams: [HitBeam] = []
    private(set) var payout: PayoutPopup?
    var layout = ArenaLayout()
    /// Turned off when a battle's 60-second timer ends; later reps don't score.
    var isAcceptingReps = true
    /// Called after every counted rep so the session can checkpoint to disk.
    @ObservationIgnored var onRep: (() -> Void)?

    var hasActiveEffects: Bool {
        !coinBursts.isEmpty || !shardBursts.isEmpty || !rings.isEmpty || !beams.isEmpty
    }

    var hitsTaken: Int { spec.health - health }

    @ObservationIgnored let camera = PoseCameraService()
    @ObservationIgnored private var detector = RepDetector()
    @ObservationIgnored private let sound = SoundService()
    @ObservationIgnored private let haptics = HapticService()
    @ObservationIgnored private var effectID = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isCelebrating = false
    @ObservationIgnored private var jointSeen: [Joint: Double] = [:]
    @ObservationIgnored private var hasStarted = false
    /// This session's block order; every session opens with an easy crate.
    @ObservationIgnored private let tierPlan: [BlockTier]

    /// The exercise being counted this session; drives rep detection and cues.
    let exercise: Exercise

    /// - Parameter firstBlockHealth: Overrides the hits needed for the first
    ///   crate (used by the onboarding intro, which smashes one box in 4 reps).
    init(exercise: Exercise = .pushUps, firstBlockHealth: Int? = nil) {
        self.exercise = exercise
        detector.exercise = exercise
        tierPlan = firstBlockHealth == nil ? BlockPlan.random() : BlockPlan.sequences[0]
        if let firstBlockHealth {
            spec = BlockSpec(level: 0, tier: .crate, health: firstBlockHealth, payout: BlockTier.crate.basePayout)
            health = firstBlockHealth
        }
    }

    // MARK: - Lifecycle

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        haptics.prepare()
        if !hasStarted {
            hasStarted = true
            land(after: 0.45)
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    startCamera()
                } else {
                    cameraStatus = .denied
                }
            }
        default:
            cameraStatus = .denied
        }
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        camera.stop()
    }

    func recalibrate() {
        haptics.tap()
        detector.reset()
        tracking = detector.state
        updateCue()
    }

    func resetGame() {
        haptics.tap()
        generation += 1
        reps = 0
        coins = 0
        displayedCoins = 0
        coinBursts = []
        shardBursts = []
        rings = []
        beams = []
        payout = nil
        isCelebrating = false
        spawn(level: 0)
    }

    // MARK: - Camera

    private func startCamera() {
        camera.onFrame = { [weak self] frame in
            Task { @MainActor in
                self?.handle(frame)
            }
        }
        camera.start { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .running: self.cameraStatus = .running
                case .noCamera: self.cameraStatus = .noCamera
                case .failed: self.cameraStatus = .failed
                }
            }
        }
    }

    private func handle(_ frame: PoseFrame) {
        let now = CACurrentMediaTime()
        let event = detector.process(frame, now: now)
        if detector.state != tracking {
            tracking = detector.state
        }
        updatePose(frame, now: now)
        updateCue()

        if event.justCharged {
            haptics.charged()
        }
        if event.repCompleted {
            registerRep(power: event.power)
        }
    }

    private func updatePose(_ frame: PoseFrame, now: Double) {
        var joints: [Joint: CGPoint] = [:]
        for (joint, point) in frame.joints {
            jointSeen[joint] = now
            if let old = pose.joints[joint] {
                joints[joint] = CGPoint(x: old.x + (point.x - old.x) * 0.65, y: old.y + (point.y - old.y) * 0.65)
            } else {
                joints[joint] = point
            }
        }
        // Keep briefly-dropped joints so the skeleton doesn't flicker.
        for (joint, point) in pose.joints where joints[joint] == nil {
            if now - (jointSeen[joint] ?? 0) < 0.25 {
                joints[joint] = point
            }
        }
        pose = DisplayPose(joints: joints, imageSize: frame.imageSize)
    }

    private func updateCue() {
        let next: CoachCue
        if isCelebrating {
            next = .smashed
        } else {
            switch tracking.phase {
            case .searching: next = .getInFrame
            case .calibrating: next = .holdTop
            case .top, .charging: next = .goDown
            case .charged: next = .smashIt
            }
        }
        if next != cue {
            cue = next
        }
    }
    // MARK: - Game

    private func registerRep(power: Double) {
        guard isAcceptingReps else { return }
        reps += 1
        defer { onRep?() }
        guard blockPhase == .idle, health > 0 else { return }
        hit(power: power)
    }

    private func hit(power: Double) {
        health -= 1
        hitCount += 1
        let now = Date.timeIntervalSinceReferenceDate
        let frame = layout.blockFrame
        let impact = CGPoint(x: frame.midX, y: frame.maxY)

        sound.play(.hit, pitch: Float(1.12 - 0.28 * power), volume: Float(0.95 + 0.05 * power))
        haptics.hit(power: power)

        rings.append(ShockRing(id: nextID(), start: now, origin: impact, power: power, color: spec.tier.accent, isBig: false))
        if let head = headPoint() {
            beams.append(HitBeam(id: nextID(), start: now, from: head, to: impact, color: spec.tier.accent))
        }
        scheduleCleanup(after: 0.6)

        if health <= 0 {
            smash()
        }
    }

    private func smash() {
        let gen = generation
        let amount = spec.payout
        let now = Date.timeIntervalSinceReferenceDate
        let frame = layout.blockFrame
        let center = CGPoint(x: frame.midX, y: frame.midY)

        blockPhase = .shattered
        isCelebrating = true
        smashCount += 1
        coins += amount
        updateCue()

        sound.play(.shatter, pitch: 1, volume: 1)
        haptics.smash()

        shardBursts.append(ShardBurst.make(id: nextID(), start: now, origin: center, color: spec.tier.shardColor, count: 22))
        rings.append(ShockRing(id: nextID(), start: now, origin: center, power: 1, color: spec.tier.accent, isBig: true))
        payout = PayoutPopup(id: nextID(), amount: amount)

        let burst = CoinBurst.make(
            id: nextID(),
            start: now,
            origin: center,
            target: layout.coinTarget,
            count: Self.coinsPerBurst
        )
        coinBursts.append(burst)

        let perCoin = amount / Self.coinsPerBurst
        let remainder = amount % Self.coinsPerBurst
        for (index, coin) in burst.coins.enumerated() {
            let share = perCoin + (index < remainder ? 1 : 0)
            after(coin.arrival, gen: gen) { [weak self] in
                guard let self else { return }
                self.displayedCoins += share
                if index % 2 == 0 { self.haptics.coinTick() }
            }
        }
        after(0.42, gen: gen) { [weak self] in
            self?.sound.play(.coins, pitch: 1, volume: 1)
        }
        after(1.25, gen: gen) { [weak self] in
            self?.payout = nil
        }
        after(burst.end - now + 0.1, gen: gen) { [weak self] in
            guard let self else { return }
            self.displayedCoins = self.coins
            self.pruneEffects()
        }
        after(0.5, gen: gen) { [weak self] in
            guard let self else { return }
            self.isCelebrating = false
            self.spawn(level: self.spec.level + 1)
            self.updateCue()
        }
    }

    private func spawn(level: Int) {
        spec = BlockSpec.make(level: level, tier: BlockPlan.tier(at: level, plan: tierPlan))
        health = spec.health
        blockID += 1
        blockSeed = UInt64.random(in: 1...UInt64.max)
        blockPhase = .dropping
        sound.play(.drop, pitch: level >= BlockTier.alloy.rawValue ? 0.85 : 1, volume: 1)
        land(after: 0.38)
    }

    private func land(after delay: Double) {
        let gen = generation
        after(delay, gen: gen) { [weak self] in
            guard let self, self.blockPhase == .dropping else { return }
            self.blockPhase = .idle
            self.haptics.land()
        }
    }

    // MARK: - Helpers

    private func headPoint() -> CGPoint? {
        guard let point = pose.joints[.nose] ?? pose.joints[.neck] else { return nil }
        return PoseMapper.map(point, imageSize: pose.imageSize, viewSize: layout.screenSize)
    }

    private func nextID() -> Int {
        effectID += 1
        return effectID
    }

    private func after(_ delay: Double, gen: Int, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(delay, 0)))
            guard let self, self.generation == gen else { return }
            action()
        }
    }

    private func scheduleCleanup(after delay: Double) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.pruneEffects()
        }
    }

    private func pruneEffects() {
        let now = Date.timeIntervalSinceReferenceDate
        rings.removeAll { now - $0.start > ShockRing.lifetime + 0.05 }
        beams.removeAll { now - $0.start > HitBeam.lifetime + 0.05 }
        shardBursts.removeAll { now - $0.start > ShardBurst.lifetime + 0.05 }
        coinBursts.removeAll { now > $0.end + 0.05 }
    }
}
