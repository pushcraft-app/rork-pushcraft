import CoreGraphics
import Foundation

/// Live tracking state published to the UI.
nonisolated struct RepTracking: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case searching
        /// Holding still, calibrating (arms verified straight for push-ups).
        case calibrating
        /// Holding still but no arm chain is visible to verify the start.
        case noArm
        case top
        case charging
        case charged
    }

    var phase: Phase
    /// 0...1 — how far down the user is relative to their calibrated range.
    var depth: Double
    /// 0...1 — progress of the "hold the top" calibration.
    var calibration: Double

    static let initial = RepTracking(phase: .searching, depth: 0, calibration: 0)
}

/// Things that happened on the latest frame.
nonisolated struct RepEvent: Sendable {
    var repCompleted = false
    var justCharged = false
    /// 0...1 — how far past the charge threshold the user went on this rep.
    var power: Double = 0
}

/// Turns a stream of body poses into reps for the selected exercise.
///
/// - Anchor: the neck (midpoint of the shoulders), falling back to one shoulder or the nose
///   with a learned nose→neck offset, then low-pass filtered.
/// - Auto-calibration: the user holds the start position still for ~1 s; the shoulder span sets
///   the expected travel so the thresholds scale with distance from the camera.
/// - Direction: push-ups charge while the anchor sinks (torso down); sit-ups charge while it
///   rises (torso up from lying flat) — same hysteresis, mirrored.
/// - Straight-arm check: push-up calibration can only complete when one arm's chain
///   (shoulder + elbow + wrist) is visible and near-straight, so holding still at the
///   bottom can never lock in a false "top". Collinearity survives projection, so a
///   foreshortened but straight arm still passes. Sit-ups skip the check — lying flat
///   IS their start position.
/// - Readiness: a live flag for the pre-start countdown. Ready = calibrated, near the
///   top, and visible. Lost only by a clear lowering (past 50 % of the range for 0.3 s)
///   or by the full tracking-loss reset — never by jitter or a brief flicker.
/// - Hysteresis: charged at 55 % of the range, rep counted on the way back above 25 %,
///   with a 0.35 s debounce so jittery tracking can't double-count.
nonisolated struct RepDetector: Sendable {
    static let downThreshold = 0.55
    static let upThreshold = 0.25
    static let debounce = 0.35
    static let calibrationDuration = 1.0
    static let calibrationTolerance = 0.035
    static let lostTimeout = 2.5
    static let straightArmAngle: Double = 150
    static let loweredDepth = 0.5
    static let loweredSeconds = 0.3

    /// Which movement is being counted. Sit-ups invert the charge direction
    /// (the torso rises instead of sinking) and use a wider travel range.
    var exercise: Exercise = .pushUps

    private(set) var state = RepTracking.initial

    private var filtered: Double?
    private var top: Double?
    private var range = 0.12
    private var minRange = 0.08
    private var noseToNeck = 0.07
    private var lastSeen = -Double.infinity

    private var calibrationStart: Double?
    private var calibrationMin = 0.0
    private var calibrationMax = 0.0
    private var calibrationSum = 0.0
    private var calibrationCount = 0
    private var spanSum = 0.0
    private var spanCount = 0

    private var isCharged = false
    private var peak = 0.0
    private var lastRep = -Double.infinity

    private var isLowered = false
    private var lowerStart: Double?

    /// Live readiness for the pre-start countdown: calibrated, near the top,
    /// body visible. Only meaningful before the workout starts.
    private(set) var isReady = false

    /// +1 for push-ups (charge while the anchor sinks), −1 for sit-ups
    /// (charge while the anchor rises).
    private var direction: Double { exercise == .sitUps ? -1 : 1 }

    mutating func reset() {
        self = RepDetector()
    }

    mutating func process(_ frame: PoseFrame, now: Double) -> RepEvent {
        var event = RepEvent()

        guard let raw = anchor(in: frame) else {
            if now - lastSeen > Self.lostTimeout {
                filtered = nil
                top = nil
                isCharged = false
                isLowered = false
                lowerStart = nil
                isReady = false
                calibrationStart = nil
                state = .initial
            }
            return event
        }
        lastSeen = now

        let y = filtered.map { $0 + (raw - $0) * 0.45 } ?? raw
        filtered = y

        guard let currentTop = top else {
            calibrate(y: y, frame: frame, now: now)
            return event
        }

        let delta = y - currentTop
        var depth = direction * delta / range

        if !isCharged {
            if delta * direction < 0 {
                // Moving in the "rest" direction past the start — raise the bar quickly.
                top = currentTop + delta * 0.25
            } else if depth < 0.2 {
                top = currentTop + delta * 0.02
            }
        }
        depth = max(0, depth)

        if !isCharged {
            if depth >= Self.downThreshold {
                isCharged = true
                peak = depth
                event.justCharged = true
            }
        } else {
            peak = max(peak, depth)
            if depth <= Self.upThreshold {
                isCharged = false
                if now - lastRep >= Self.debounce {
                    lastRep = now
                    event.repCompleted = true
                    event.power = min(max((peak - Self.downThreshold) / (1 - Self.downThreshold), 0), 1)
                    learn(from: peak)
                }
            }
        }

        updateReadiness(depth: depth, now: now)

        let phase: RepTracking.Phase = isCharged ? .charged : (depth > 0.08 ? .charging : .top)
        state = RepTracking(phase: phase, depth: min(depth, 1), calibration: 1)
        return event
    }

    /// Keeps the top-position calibration but forgets any charge, peak depth
    /// and pending setup movement, so the first counted rep must be a fresh
    /// down-and-up. Called at GO.
    mutating func clearCharge() {
        isCharged = false
        peak = 0
    }

    private mutating func updateReadiness(depth: Double, now: Double) {
        if depth >= Self.loweredDepth {
            if lowerStart == nil { lowerStart = now }
            if now - lowerStart! >= Self.loweredSeconds { isLowered = true }
        } else {
            lowerStart = nil
            if depth <= Self.upThreshold { isLowered = false }
        }
        isReady = top != nil && !isLowered
    }

    // MARK: - Private

    private mutating func calibrate(y: Double, frame: PoseFrame, now: Double) {
        let isStill = calibrationStart != nil
            && max(calibrationMax, y) - min(calibrationMin, y) <= Self.calibrationTolerance
        if !isStill {
            // Moved too much (or just started) — restart the one-second hold.
            calibrationStart = now
            calibrationMin = y
            calibrationMax = y
            calibrationSum = 0
            calibrationCount = 0
            spanSum = 0
            spanCount = 0
        }
        calibrationMin = min(calibrationMin, y)
        calibrationMax = max(calibrationMax, y)
        calibrationSum += y
        calibrationCount += 1
        if let span = shoulderSpan(in: frame) {
            spanSum += span
            spanCount += 1
        }

        let progress = min((now - (calibrationStart ?? now)) / Self.calibrationDuration, 1)
        if progress >= 1, calibrationCount > 0 {
            // Push-ups may never calibrate on stillness alone: the start
            // position must be verified straight-armed via one visible arm.
            if exercise == .pushUps, !hasStraightArm(in: frame) {
                state = RepTracking(phase: .noArm, depth: 0, calibration: progress)
                return
            }
            top = calibrationSum / Double(calibrationCount)
            let span = spanCount > 0 ? spanSum / Double(spanCount) : 0.2
            // Sit-ups rotate the whole torso, so expect a much larger travel.
            let factor = exercise == .sitUps ? 0.85 : 0.55
            let bounds = exercise == .sitUps ? (0.10, 0.30) : (0.06, 0.22)
            range = min(max(span * factor, bounds.0), bounds.1)
            minRange = range * 0.8
            isCharged = false
            isLowered = false
            lowerStart = nil
            isReady = true
            calibrationStart = nil
            state = RepTracking(phase: .top, depth: 0, calibration: 1)
        } else {
            let armsOK = exercise == .sitUps || hasStraightArm(in: frame)
            state = RepTracking(phase: armsOK ? .calibrating : .noArm, depth: 0, calibration: progress)
        }
    }

    /// True when either arm's shoulder-elbow-wrist chain is visible and near
    /// straight. Collinearity survives projection, so this works from any
    /// camera angle where the chain is visible at all.
    private func hasStraightArm(in frame: PoseFrame) -> Bool {
        guard frame.imageSize.height > 0 else { return false }
        let aspect = frame.imageSize.width / frame.imageSize.height
        for arm in [Arm.left, .right] where arm.isStraight(in: frame, aspect: aspect) {
            return true
        }
        return false
    }

    private enum Arm {
        case left, right

        func isStraight(in frame: PoseFrame, aspect: CGFloat) -> Bool {
            let joints = frame.joints
            switch self {
            case .left:
                guard let s = joints[.leftShoulder], let e = joints[.leftElbow], let w = joints[.leftWrist] else { return false }
                return Self.angle(s, e, w, aspect: aspect) >= RepDetector.straightArmAngle
            case .right:
                guard let s = joints[.rightShoulder], let e = joints[.rightElbow], let w = joints[.rightWrist] else { return false }
                return Self.angle(s, e, w, aspect: aspect) >= RepDetector.straightArmAngle
            }
        }

        /// Interior elbow angle in degrees. X is rescaled by the image aspect
        /// so the normalized coordinates measure true angles.
        private static func angle(_ shoulder: CGPoint, _ elbow: CGPoint, _ wrist: CGPoint, aspect: CGFloat) -> Double {
            func vector(_ from: CGPoint, _ to: CGPoint) -> CGPoint {
                CGPoint(x: (to.x - from.x) * aspect, y: to.y - from.y)
            }
            let u = vector(elbow, shoulder)
            let v = vector(elbow, wrist)
            let dot = Double(u.x * v.x + u.y * v.y)
            let magnitude = sqrt(Double(u.x * u.x + u.y * u.y)) * sqrt(Double(v.x * v.x + v.y * v.y))
            guard magnitude > 1e-6 else { return 0 }
            return acos(min(max(dot / magnitude, -1), 1)) * 180 / .pi
        }
    }

    private mutating func learn(from peak: Double) {
        let travel = peak * range
        let blended = range * 0.75 + travel * 0.25
        let ceiling = exercise == .sitUps ? 0.38 : 0.3
        range = min(max(blended, minRange), ceiling)
    }

    private mutating func anchor(in frame: PoseFrame) -> Double? {
        let joints = frame.joints
        let neck = joints[.neck]
        let nose = joints[.nose]

        if let neck, let nose {
            noseToNeck += ((neck.y - nose.y) - noseToNeck) * 0.05
        }
        if let neck { return neck.y }
        if let left = joints[.leftShoulder], let right = joints[.rightShoulder] {
            return (left.y + right.y) / 2
        }
        if let shoulder = joints[.leftShoulder] ?? joints[.rightShoulder] {
            return shoulder.y
        }
        if let nose { return nose.y + noseToNeck }
        return nil
    }

    private func shoulderSpan(in frame: PoseFrame) -> Double? {
        guard let left = frame.joints[.leftShoulder],
              let right = frame.joints[.rightShoulder],
              frame.imageSize.height > 0 else { return nil }
        return abs(left.x - right.x) * frame.imageSize.width / frame.imageSize.height
    }
}
