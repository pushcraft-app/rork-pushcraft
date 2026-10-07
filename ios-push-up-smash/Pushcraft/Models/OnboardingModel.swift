import Foundation
import Observation
import SwiftUI
import UserNotifications

/// Every screen in the first-run flow.
enum OnboardingStep: Hashable {
    case welcome, signIn
    case meetGuide, name, mainGoal, experience, gender, age, height
    case frequency, boredom, equipment, seeingProgress, journey, howBuild
    case pushupCapacity, workoutDays, reminder
    case firstBuild, phoneSetup, pushupForm, detectionTips, introWorkout, firstReward, forecast, saveProgress

    /// Screens that show the questionnaire progress bar (02 → 17).
    static let questionnaire: [OnboardingStep] = [
        .meetGuide, .name, .mainGoal, .experience, .gender, .age, .height,
        .frequency, .boredom, .equipment, .seeingProgress, .journey, .howBuild,
        .pushupCapacity, .workoutDays, .reminder
    ]

    var progress: Double? {
        guard let index = Self.questionnaire.firstIndex(of: self) else { return nil }
        return Double(index + 1) / Double(Self.questionnaire.count)
    }
}

extension OnboardingStep {
    /// Snake-case name used in analytics events.
    var analyticsName: String {
        switch self {
        case .welcome: "welcome"
        case .signIn: "sign_in"
        case .meetGuide: "meet_guide"
        case .name: "name"
        case .mainGoal: "main_goal"
        case .experience: "experience"
        case .gender: "gender"
        case .age: "age"
        case .height: "height"
        case .frequency: "frequency"
        case .boredom: "boredom"
        case .equipment: "equipment"
        case .seeingProgress: "seeing_progress"
        case .journey: "journey"
        case .howBuild: "how_build"
        case .pushupCapacity: "pushup_capacity"
        case .workoutDays: "workout_days"
        case .reminder: "reminder"
        case .firstBuild: "first_build"
        case .phoneSetup: "phone_setup"
        case .pushupForm: "pushup_form"
        case .detectionTips: "detection_tips"
        case .introWorkout: "intro_workout"
        case .firstReward: "first_reward"
        case .forecast: "forecast"
        case .saveProgress: "save_progress"
        }
    }

    /// 1-based position along the expected first-run path (0 if off-path).
    var analyticsOrder: Int {
        Self.analyticsPath.firstIndex(of: self).map { $0 + 1 } ?? 0
    }

    /// The expected first-run path in order; `sign_in` is the detour after Welcome.
    static let analyticsPath: [OnboardingStep] = [
        .welcome, .signIn, .meetGuide, .name, .mainGoal, .experience, .gender, .age,
        .height, .frequency, .boredom, .equipment, .seeingProgress, .journey, .howBuild,
        .pushupCapacity, .workoutDays, .reminder, .firstBuild, .phoneSetup, .pushupForm,
        .detectionTips, .introWorkout, .firstReward, .forecast, .saveProgress
    ]
}

/// Answers and navigation for onboarding. Lives on AppState so the answers
/// survive the switch from signed-out to signed-in at the sign-up step.
@Observable
final class OnboardingModel {
    static let firstTowerName = "Oakspire"
    static let firstStageName = "The Foundation"
    static let firstTowerReps = 450
    static let sessionGoal = 30
    static let introReps = 4

    private(set) var history: [OnboardingStep] = [.welcome]
    private(set) var isForward = true

    var name = ""
    var mainGoal: MainGoal?
    var experience: ExperienceLevel?
    var gender: GenderChoice?
    var ageYears = 25
    var hasConfirmedAge = false
    var heightCm: Double = 170
    var heightUnit: HeightUnit = .cm
    var hasConfirmedHeight = false
    var frequency: ExerciseFrequency?
    var boredom: Agreement?
    var equipment: Agreement?
    var seeingProgress: Agreement?
    var pushupCapacity: PushupCapacity?
    var workoutDays: Set<Int> = []
    var remindersRequested = false
    var reminderTime: Date = OnboardingModel.defaultReminderTime
    var notificationStatus: String?
    /// Live notification permission while the reminder screen is up.
    var currentNotificationStatus: String?
    var isRequestingNotifications = false
    var showDeniedMessage = false
    private(set) var introRepsDone: Int?

    /// Set when sign-in starts from the "Save your progress" step.
    var awaitingSignUp = false
    /// True while the post-sign-up "setting everything up" screen shows.
    private(set) var isSettingUp = false

    var step: OnboardingStep { history.last ?? .welcome }

    var canGoBack: Bool {
        switch step {
        case .welcome, .introWorkout, .firstReward: false
        case .forecast: !didIntroWorkout && history.count > 1
        default: history.count > 1
        }
    }

    var trimmedName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
    }

    var nameOrBuilder: String { trimmedName.isEmpty ? "builder" : trimmedName }
    var didIntroWorkout: Bool { introRepsDone != nil }

    // MARK: - Navigation

    func advance(to next: OnboardingStep) {
        isForward = true
        AnalyticsService.trackOnboardingStep(name: next.analyticsName, order: next.analyticsOrder)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            history.append(next)
        }
    }

    func back() {
        guard canGoBack else { return }
        isForward = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            _ = history.removeLast()
        }
    }

    func finishIntro(reps: Int) {
        introRepsDone = reps
        advance(to: .firstReward)
    }

    func beginSetupIfNeeded() {
        guard awaitingSignUp else { return }
        awaitingSignUp = false
        isSettingUp = true
    }

    func finishSetup() {
        isSettingUp = false
        AnalyticsService.trackOnboardingCompleted(
            workoutDaysPerWeek: workoutDays.count,
            introReps: introRepsDone,
            remindersRequested: remindersRequested
        )
    }

    /// Back to a clean Welcome screen (after sign-out or account deletion).
    func reset() {
        history = [.welcome]
        isForward = true
        name = ""
        mainGoal = nil
        experience = nil
        gender = nil
        ageYears = 25
        hasConfirmedAge = false
        heightCm = 170
        heightUnit = .cm
        hasConfirmedHeight = false
        frequency = nil
        boredom = nil
        equipment = nil
        seeingProgress = nil
        pushupCapacity = nil
        workoutDays = []
        remindersRequested = false
        reminderTime = Self.defaultReminderTime
        notificationStatus = nil
        currentNotificationStatus = nil
        isRequestingNotifications = false
        showDeniedMessage = false
        introRepsDone = nil
        awaitingSignUp = false
        isSettingUp = false
    }

    // MARK: - Forecast

    /// Date of the session that would finish the first tower at the
    /// workout goal on the chosen days, counting today.
    var forecastDate: Date? {
        guard !workoutDays.isEmpty else { return nil }
        let sessionsNeeded = Int((Double(Self.firstTowerReps) / Double(Self.sessionGoal)).rounded(.up))
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        var sessions = 0
        for offset in 0..<730 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if workoutDays.contains(NotificationService.isoWeekday(of: date, calendar: calendar)) {
                sessions += 1
                if sessions == sessionsNeeded { return date }
            }
        }
        return nil
    }

    var selectedDaysText: String {
        let days = Weekday.allCases.filter { workoutDays.contains($0.rawValue) }
        if days.count == 7 { return "Every day" }
        return days.map(\.short).joined(separator: ", ")
    }

    // MARK: - Saving

    func makeAnswers() -> OnboardingAnswers {
        OnboardingAnswers(
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            mainGoal: mainGoal?.serverValue,
            experience: experience?.serverValue,
            gender: gender?.serverValue,
            ageYears: hasConfirmedAge ? ageYears : nil,
            heightCm: hasConfirmedHeight ? (heightCm * 10).rounded() / 10 : nil,
            heightDisplayUnit: hasConfirmedHeight ? heightUnit.rawValue : nil,
            currentFrequency: frequency?.serverValue,
            barrierBoredom: boredom?.serverValue,
            barrierEquipment: equipment?.serverValue,
            barrierProgress: seeingProgress?.serverValue,
            pushupCapacity: pushupCapacity?.serverValue,
            workoutDays: workoutDays.sorted(),
            remindersRequested: remindersRequested,
            reminderLocalTime: remindersRequested ? Self.timeString(reminderTime) : nil,
            timezone: TimeZone.current.identifier,
            notificationStatus: notificationStatus,
            introWorkoutReps: introRepsDone
        )
    }

    /// Copies the reminder choice into the phone's notification preferences.
    func applyReminderPreferences() {
        let prefs = AppPreferences.shared
        let allowed = ["authorized", "provisional", "ephemeral"].contains(notificationStatus ?? "")
        prefs.notificationsEnabled = remindersRequested && allowed
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        prefs.reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
        prefs.reminderDays = workoutDays.sorted()
    }

    var isNotificationDenied: Bool { currentNotificationStatus == "denied" }

    /// "Enable reminders" while the user still needs to grant permission.
    var reminderPrimaryTitle: String {
        guard remindersRequested, !showDeniedMessage, !isNotificationDenied else { return "Continue" }
        return "Enable reminders"
    }

    /// Pinned-CTA action on the reminder screen: requests permission when
    /// needed, otherwise finishes the step.
    func handleReminderPrimaryTap() async {
        guard remindersRequested, !showDeniedMessage, !isNotificationDenied else {
            finishReminderStep()
            return
        }
        isRequestingNotifications = true
        let current = await NotificationService.shared.authorizationStatus()
        var granted = [.authorized, .provisional, .ephemeral].contains(current)
        if current == .notDetermined {
            granted = await NotificationService.shared.requestAuthorization()
        }
        let updated = await NotificationService.shared.authorizationStatus()
        currentNotificationStatus = Self.statusString(updated)
        isRequestingNotifications = false

        if granted {
            HapticService.ui.success()
            finishReminderStep()
        } else {
            HapticService.ui.warning()
            withAnimation { showDeniedMessage = true }
        }
    }

    /// "Not now": keep reminders off and move on.
    func skipReminders() {
        remindersRequested = false
        finishReminderStep()
    }

    private func finishReminderStep() {
        notificationStatus = currentNotificationStatus
        applyReminderPreferences()
        if AppPreferences.shared.notificationsEnabled {
            Task { await NotificationService.shared.scheduleStreakReminders(doneToday: false, streak: 0) }
        }
        advance(to: .firstBuild)
    }

    static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }

    static func timeString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 18, parts.minute ?? 0)
    }

    static func statusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: "authorized"
        case .denied: "denied"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        default: "not_determined"
        }
    }
}
