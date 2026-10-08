import Foundation
import Mixpanel

/// Thin facade over Mixpanel for the new-user funnel: onboarding screens,
/// sign-up, paywall, subscription, and the workout value moment. Every call
/// is a safe no-op until `configure()` succeeds, so a missing project token
/// simply disables tracking without affecting the app.
enum AnalyticsService {
    private static var instance: MixpanelInstance?

    /// Initializes Mixpanel with the project token injected at build time.
    static func configure() {
        // Looked up by name so the app compiles even before the env var is
        // registered; an empty value simply leaves tracking disabled.
        let token = (Config.allValues["EXPO_PUBLIC_MIXPANEL_TOKEN"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            print("[Analytics] No Mixpanel token — tracking disabled")
            return
        }
        instance = Mixpanel.initialize(token: token, trackAutomaticEvents: false)
        #if DEBUG
        instance?.loggingEnabled = true
        #endif
    }

    // MARK: - Funnel events

    static func trackAppOpen() {
        track("app_open")
    }

    /// The Welcome screen appeared for a signed-out visitor.
    static func trackOnboardingStarted() {
        track("onboarding_started")
    }

    /// One event per onboarding screen, with its snake-case name and 1-based position.
    static func trackOnboardingStep(name: String, order: Int) {
        track("onboarding_step_viewed", ["step": name, "step_order": order])
    }

    /// The post-sign-up "setting everything up" screen finished.
    static func trackOnboardingCompleted(workoutDaysPerWeek: Int, introReps: Int?, remindersRequested: Bool) {
        var properties: Properties = [
            "workout_days_per_week": workoutDaysPerWeek,
            "reminders_requested": remindersRequested
        ]
        if let introReps { properties["intro_workout_reps"] = introReps }
        track("onboarding_completed", properties)
    }

    /// New account created from the onboarding flow.
    static func trackSignUp(method: String) {
        track("sign_up_completed", ["method": method])
        instance?.people.setOnce(properties: ["signup_method": method])
    }

    /// Existing account signed in — kept out of the new-user funnel.
    static func trackSignIn(method: String) {
        track("sign_in_completed", ["method": method])
    }

    static func trackPaywallViewed(hasIntroOffer: Bool, weeklyPrice: String?, yearlyPrice: String?) {
        var properties: Properties = ["has_intro_offer": hasIntroOffer]
        if let weeklyPrice { properties["weekly_price"] = weeklyPrice }
        if let yearlyPrice { properties["yearly_price"] = yearlyPrice }
        track("paywall_viewed", properties)
    }

    static func trackPurchaseStarted(plan: String, productID: String?, hasIntroOffer: Bool) {
        var properties: Properties = ["plan": plan, "has_intro_offer": hasIntroOffer]
        if let productID { properties["product_id"] = productID }
        track("purchase_started", properties)
    }

    static func trackSubscriptionStarted(plan: String, productID: String?, hasIntroOffer: Bool) {
        var properties: Properties = ["plan": plan, "has_intro_offer": hasIntroOffer]
        if let productID { properties["product_id"] = productID }
        track("subscription_started", properties)
        setPlan("premium")
        instance?.people.setOnce(properties: ["first_subscription_at": Date()])
    }

    static func trackPurchaseCancelled(plan: String) {
        track("purchase_cancelled", ["plan": plan])
    }

    static func trackPurchasePending(plan: String) {
        track("purchase_pending", ["plan": plan])
    }

    static func trackPurchaseFailed(plan: String) {
        track("purchase_failed", ["plan": plan])
    }

    static func trackPurchaseRestored() {
        track("purchase_restored")
        setPlan("premium")
    }

    /// The value moment: an accepted workout outcome stored on the server.
    static func trackWorkoutCompleted(
        reps: Int,
        isCompleted: Bool,
        isBattle: Bool,
        blocksSmashed: Int,
        coinsAwarded: Int,
        endReason: String
    ) {
        let isFirst = !AppPreferences.shared.hasTrackedWorkout
        track("workout_completed", [
            "reps": reps,
            "is_completed": isCompleted,
            "is_battle": isBattle,
            "blocks_smashed": blocksSmashed,
            "coins_awarded": coinsAwarded,
            "end_reason": endReason,
            "is_first_workout": isFirst
        ])
        if let instance {
            instance.people.increment(properties: ["total_workouts": 1, "total_reps": reps])
            instance.people.set(properties: ["last_workout_at": Date()])
            if isFirst {
                instance.people.setOnce(properties: ["first_workout_at": Date()])
            }
        }
        if isFirst {
            AppPreferences.shared.hasTrackedWorkout = true
        }
    }

    // MARK: - Identity & profiles

    /// Links the anonymous visitor to the account ID; earlier onboarding events
    /// merge into the same user automatically. Stamps the profile basics.
    static func identify(userID: UUID, email: String?, name: String?) {
        guard let instance else { return }
        instance.identify(distinctId: userID.uuidString.lowercased())
        var properties: Properties = [:]
        if let email, !email.isEmpty { properties["$email"] = email }
        if let name, !name.isEmpty { properties["$name"] = name }
        if !properties.isEmpty {
            instance.people.set(properties: properties)
        }
    }

    /// Records the onboarding answers on the profile (once, at sign-up).
    static func setOnboardingProfile(
        mainGoal: String?,
        experience: String?,
        gender: String?,
        ageYears: Int?,
        workoutDaysPerWeek: Int,
        remindersRequested: Bool
    ) {
        guard let instance else { return }
        var properties: Properties = [
            "workout_days_per_week": workoutDaysPerWeek,
            "reminders_requested": remindersRequested
        ]
        if let mainGoal { properties["main_goal"] = mainGoal }
        if let experience { properties["experience"] = experience }
        if let gender { properties["gender"] = gender }
        if let ageYears { properties["age"] = ageYears }
        instance.people.set(properties: properties)
    }

    static func setPlan(_ plan: String) {
        instance?.people.set(properties: ["plan": plan])
    }

    /// Returns tracking to anonymous mode (sign-out / account deletion).
    static func reset() {
        instance?.reset()
    }

    // MARK: - Core

    private static func track(_ event: String, _ properties: Properties? = nil) {
        instance?.track(event: event, properties: properties)
    }
}
