import CoreGraphics
import Foundation

/// Live tracking state published to the UI.
nonisolated struct RepTracking: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case searching
        /// A person is visible but standing up — tracking is paused until
        /// they get into the exercise position.
        case wrongPosition
        case calibrating
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
/// - Posture gate: the torso angle (mid-shoulder → mid-hip) must be roughly
///   horizontal before anything is calibrated or counted — a standing person
///   can never calibrate, fill the bar, or score, and standing up mid-workout
///   wipes the calibration so it restarts cleanly when they lie back down.
/// - Auto-calibration: the user holds the start position still for ~1 s; the shoulder span sets
///   the expected travel so the thresholds scale with distance from the camera.
/// - Direction: push-ups charge while the anchor sinks (torso down); sit-ups charge while it
///   rises (torso up from lying flat) — same hysteresis, mirrored.
/// - Hysteresis: charged at 55 % of the range, rep counted on the way back above 25 %,
///   with a 0.35 s debounce so jittery tracking can't double-count.
nonisolated struct RepDetector: Sendable {
    static let downThreshold = 0.55
    static let upThreshold = 0.25
    static let debounce = 0.35
    static let calibrationDuration = 1.0
    static let calibrationTolerance = 0.035
    static let lostTimeout = 2.5

    /// Posture gate: the torso angle from the image's vertical axis must rise
    /// above `lyingAngle` (deg) to count as lying down and fall below
    /// `uprightAngle` to count as standing up (hysteresis between the two).
    static let lyingAngle = 50.0
    static let uprightAngle = 35.0
    /// Seconds clearly upright before tracking resets. Kept below
    /// `calibrationDuration` so a standing hold can never finish calibrating.
    static let uprightResetDelay = 0.9

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

    /// Whether the user is currently in the exercise position (torso roughly
    /// horizontal). Starts true so a hidden-hips camera angle degrades to the
    /// old, ungated behaviour instead of blocking forever.
    private var isLying = true
    private var uprightSince: Double?

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
                calibrationStart = nil
                state = .initial
            }
            return event
        }
        lastSeen = now

        // Posture gate: a standing person must never calibrate or fill the
        // bar, and standing up mid-workout wipes the calibration so the next
        // rep always starts from a fresh, honest range.
        if let angle = torsoAngle(fromVerticalIn: frame) {
            if !isLying, angle >= Self.lyingAngle {
                isLying = true
                uprightSince = nil
            } else if isLying, angle < Self.uprightAngle {
                let since = uprightSince ?? now
                uprightSince = since
                // Mid-rep poses (e.g. the top of a sit-up) lean vertical, so
                // give a charged rep more time before calling it standing.
                let limit = isCharged ? Self.uprightResetDelay + 1.2 : Self.uprightResetDelay
                if now - since >= limit {
                    isLying = false
                    uprightSince = nil
                    filtered = nil
                    top = nil
                    isCharged = false
                    calibrationStart = nil
                    state = RepTracking(phase: .wrongPosition, depth: 0, calibration: 0)
                    return event
                }
            } else {
                uprightSince = nil
            }
        }
        guard isLying else {
            filtered = nil
            top = nil
            isCharged = false
            calibrationStart = nil
            state = RepTracking(phase: .wrongPosition, depth: 0, calibration: 0)
            return event
        }

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

        let phase: RepTracking.Phase = isCharged ? .charged : (depth > 0.08 ? .charging : .top)
        state = RepTracking(phase: phase, depth: min(depth, 1), calibration: 1)
        return event
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
            top = calibrationSum / Double(calibrationCount)
            let span = spanCount > 0 ? spanSum / Double(spanCount) : 0.2
            // Sit-ups rotate the whole torso, so expect a much larger travel.
            let factor = exercise == .sitUps ? 0.85 : 0.55
            let bounds = exercise == .sitUps ? (0.10, 0.30) : (0.06, 0.22)
            range = min(max(span * factor, bounds.0), bounds.1)
            minRange = range * 0.8
            isCharged = false
            calibrationStart = nil
            state = RepTracking(phase: .top, depth: 0, calibration: 1)
        } else {
            state = RepTracking(phase: .calibrating, depth: 0, calibration: progress)
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

    /// Angle of the torso (mid-shoulder → mid-hip) away from the image's
    /// vertical axis, in degrees: ~0° upright, ~90° lying flat. Nil when the
    /// shoulders and hips aren't both visible enough to judge.
    private func torsoAngle(fromVerticalIn frame: PoseFrame) -> Double? {
        let joints = frame.joints
        let shoulderMid = Self.mid(joints[.leftShoulder], joints[.rightShoulder]) ?? joints[.neck]
        let hipMid = Self.mid(joints[.leftHip], joints[.rightHip]) ?? joints[.root]
        guard let shoulderMid, let hipMid else { return nil }
        let dx = hipMid.x - shoulderMid.x
        let dy = hipMid.y - shoulderMid.y
        let length = (dx * dx + dy * dy).squareRoot()
        // Too foreshortened to judge reliably (e.g. head-on and far away).
        guard length > 0.015 else { return nil }
        let cosine = min(max(dy / length, -1), 1)
        return acos(cosine) * 180 / .pi
    }

    private static func mid(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): a
        case let (nil, b?): b
        case (nil, nil): nil
        }
    }
}
