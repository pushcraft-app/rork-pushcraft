import Foundation
import UserNotifications

/// Local build reminders scheduled on the phone at the user's chosen time and
/// days. These replace server-sent push notifications (deferred scope).
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let identifiers = (0..<14).map { "streak-reminder-\($0)" }

    /// Current OS permission state, without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the OS permission dialog. Only call after the user opts in.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Asks for permission once, only when reminders are enabled.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        guard AppPreferences.shared.notificationsEnabled else { return false }
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        default:
            return false
        }
    }

    /// Schedules reminders for the next two weeks on the chosen build days,
    /// skipping today once today's workout is done. Never prompts for permission.
    func scheduleStreakReminders(doneToday: Bool, streak: Int) async {
        clearReminders()
        let prefs = AppPreferences.shared
        guard prefs.notificationsEnabled else { return }
        let status = await authorizationStatus()
        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = prefs.reminderMinutes / 60
        let minute = prefs.reminderMinutes % 60
        let days = Set(prefs.reminderDays)

        for offset in 0..<identifiers.count {
            if offset == 0 && doneToday { continue }
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: now),
                let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                fireDate > now
            else { continue }
            if !days.isEmpty && !days.contains(Self.isoWeekday(of: day, calendar: calendar)) { continue }

            let content = UNMutableNotificationContent()
            content.title = "Your tower is waiting"
            content.body = streak > 0
                ? "Finish a 30-rep workout today to keep your \(streak)-day streak."
                : "A quick 30-rep workout keeps your tower growing."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifiers[offset],
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    func clearReminders() {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// ISO weekday: 1 = Monday … 7 = Sunday.
    static func isoWeekday(of date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7 + 1
    }
}
