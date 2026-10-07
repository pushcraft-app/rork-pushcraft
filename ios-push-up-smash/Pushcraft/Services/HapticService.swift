import UIKit

final class HapticService {
    /// Shared instance for interface feedback (buttons, pickers, onboarding).
    static let ui = HapticService()

    /// Controlled by the Haptic preference on the Profile page.
    private var isEnabled: Bool { AppPreferences.shared.hapticsEnabled }

    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    /// Last button-tap haptic, so a press plus an explicit tap in the
    /// button's action never buzzes twice.
    private var lastTapAt: Date = .distantPast

    private func claimTap() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTapAt) > 0.35 else { return false }
        lastTapAt = now
        return true
    }

    func prepare() {
        guard isEnabled else { return }
        heavy.prepare()
        rigid.prepare()
        soft.prepare()
    }

    func charged() {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.7)
        heavy.prepare()
    }

    func hit(power: Double) {
        guard isEnabled else { return }
        heavy.impactOccurred(intensity: 0.75 + 0.25 * power)
    }

    func smash() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 1)
        heavy.impactOccurred(intensity: 1)
        notification.notificationOccurred(.success)
    }

    func coinTick() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.55)
    }

    func land() {
        guard isEnabled else { return }
        heavy.impactOccurred(intensity: 0.6)
    }

    /// Light impact at full strength for every button press.
    func tap() {
        guard isEnabled, claimTap() else { return }
        light.impactOccurred(intensity: 1)
    }

    /// Option selection: a full Light tap (deduped with the press haptic).
    func selection() {
        guard isEnabled, claimTap() else { return }
        light.impactOccurred(intensity: 1)
    }

    /// Fine tick for continuous picker scrolling.
    func tick() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Solid thud for completed steps and reveals.
    func thud() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.8)
    }
}
