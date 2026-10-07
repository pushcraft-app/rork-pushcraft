import Foundation
import Observation

/// User preferences persisted on the device with UserDefaults so they remain
/// set after reopening the app. Controls reminders, haptics and sound.
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "prefs.notifications") }
    }

    /// Reminder time as minutes after midnight in the phone's timezone.
    var reminderMinutes: Int {
        didSet { UserDefaults.standard.set(reminderMinutes, forKey: "prefs.reminderMinutes") }
    }

    /// ISO weekdays (1 = Monday … 7 = Sunday) to remind on. Empty means every day.
    var reminderDays: [Int] {
        didSet { UserDefaults.standard.set(reminderDays, forKey: "prefs.reminderDays") }
    }

    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "prefs.haptics") }
    }

    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "prefs.sound") }
    }

    /// Whether the one-time "reps save as you go" arena tip has been shown.
    var hasSeenProgressTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenProgressTip, forKey: "prefs.progressTip") }
    }

    /// Whether the one-time App Store review prompt has been requested.
    var hasAskedStoreReview: Bool {
        didSet { UserDefaults.standard.set(hasAskedStoreReview, forKey: "prefs.askedReview") }
    }

    /// Whether a workout has ever been reported to analytics (first-workout flag).
    var hasTrackedWorkout: Bool {
        didSet { UserDefaults.standard.set(hasTrackedWorkout, forKey: "prefs.trackedWorkout") }
    }

    var reminderTimeText: String {
        var components = DateComponents()
        components.hour = reminderMinutes / 60
        components.minute = reminderMinutes % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private init() {
        let defaults = UserDefaults.standard
        notificationsEnabled = (defaults.object(forKey: "prefs.notifications") as? Bool) ?? true
        reminderMinutes = (defaults.object(forKey: "prefs.reminderMinutes") as? Int) ?? 19 * 60
        reminderDays = (defaults.array(forKey: "prefs.reminderDays") as? [Int]) ?? []
        hapticsEnabled = (defaults.object(forKey: "prefs.haptics") as? Bool) ?? true
        soundEnabled = (defaults.object(forKey: "prefs.sound") as? Bool) ?? true
        hasSeenProgressTip = defaults.bool(forKey: "prefs.progressTip")
        hasAskedStoreReview = defaults.bool(forKey: "prefs.askedReview")
        hasTrackedWorkout = defaults.bool(forKey: "prefs.trackedWorkout")
    }
}
