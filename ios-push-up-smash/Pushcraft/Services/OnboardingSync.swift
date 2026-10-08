import Foundation
import Supabase

/// Onboarding answers sent to `save_onboarding` once the user has an account.
nonisolated struct OnboardingAnswers: Codable, Sendable {
    var displayName: String?
    var mainGoal: String?
    var experience: String?
    var gender: String?
    var ageYears: Int?
    var heightCm: Double?
    var heightDisplayUnit: String?
    var currentFrequency: String?
    var barrierBoredom: String?
    var barrierEquipment: String?
    var barrierProgress: String?
    var pushupCapacity: String?
    var workoutDays: [Int]
    var remindersRequested: Bool
    var reminderLocalTime: String?
    var timezone: String?
    var notificationStatus: String?
    var introWorkoutReps: Int?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case mainGoal = "main_goal"
        case experience
        case gender
        case ageYears = "age_years"
        case heightCm = "height_cm"
        case heightDisplayUnit = "height_display_unit"
        case currentFrequency = "current_frequency"
        case barrierBoredom = "barrier_boredom"
        case barrierEquipment = "barrier_equipment"
        case barrierProgress = "barrier_progress"
        case pushupCapacity = "pushup_capacity"
        case workoutDays = "workout_days"
        case remindersRequested = "reminders_requested"
        case reminderLocalTime = "reminder_local_time"
        case timezone
        case notificationStatus = "notification_status"
        case introWorkoutReps = "intro_workout_reps"
    }
}

nonisolated struct SaveOnboardingParams: Encodable, Sendable {
    let answers: OnboardingAnswers

    enum CodingKeys: String, CodingKey {
        case answers = "p_answers"
    }
}

/// Saves onboarding answers, keeping a copy on the phone (per account) until
/// the server confirms, so a dropped connection never loses them.
enum OnboardingSync {
    private static func key(for userID: UUID) -> String {
        "onboarding.pending.\(userID.uuidString.lowercased())"
    }

    @discardableResult
    static func save(_ answers: OnboardingAnswers, userID: UUID) async -> Bool {
        if let data = try? JSONEncoder().encode(answers) {
            UserDefaults.standard.set(data, forKey: key(for: userID))
        }
        return await send(answers, userID: userID)
    }

    /// Retries answers that couldn't be saved earlier.
    static func flushPending(userID: UUID) async {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: userID)),
            let answers = try? JSONDecoder().decode(OnboardingAnswers.self, from: data)
        else { return }
        await send(answers, userID: userID)
    }

    @discardableResult
    private static func send(_ answers: OnboardingAnswers, userID: UUID) async -> Bool {
        do {
            try await Backend.client.rpc("save_onboarding", params: SaveOnboardingParams(answers: answers)).execute()
            UserDefaults.standard.removeObject(forKey: key(for: userID))
            print("[Onboarding] Answers saved")
            return true
        } catch {
            print("[Onboarding] Save failed, will retry: \(error.localizedDescription)")
            return false
        }
    }
}
