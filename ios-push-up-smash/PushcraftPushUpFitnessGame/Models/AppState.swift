import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Supabase

/// App-level session: Supabase auth state plus the per-account stores.
@Observable
final class AppState {
    enum Phase: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .loading
    private(set) var userID: UUID?
    private(set) var email: String?
    private(set) var isAuthenticating = false
    var authError: String?

    let progress = ProgressStore()
    let battles = BattleStore()
    let workouts = WorkoutService()
    let store = StoreService()
    let onboarding = OnboardingModel()

    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var currentNonce: String?
    @ObservationIgnored private let appleController = AppleSignInController()
    /// Provider of the auth flow in progress ("apple"/"google"), for analytics.
    @ObservationIgnored private var pendingAuthMethod: String?

    // MARK: - Lifecycle

    /// Starts listening to Supabase auth changes. Safe to call repeatedly.
    func start() {
        guard listenTask == nil else { return }
        store.start()
        workouts.onAccepted = { [weak self] outcome in
            AnalyticsService.trackWorkoutCompleted(
                reps: outcome.reps,
                isCompleted: outcome.isCompleted,
                isBattle: outcome.battleId != nil,
                blocksSmashed: outcome.blocksSmashed,
                coinsAwarded: outcome.coinsAwarded,
                endReason: outcome.endReason
            )
            guard let self else { return }
            Task {
                await self.progress.load()
                if outcome.battleId != nil {
                    try? await self.battles.load()
                }
            }
        }
        listenTask = Task { [weak self] in
            for await change in Backend.client.auth.authStateChanges {
                guard let self else { return }
                self.handle(event: change.event, session: change.session)
            }
        }
    }

    private func handle(event: AuthChangeEvent, session: Session?) {
        guard let session, event != .signedOut else {
            if phase != .signedOut {
                print("[Auth] Signed out")
            }
            let wasSignedIn = phase == .signedIn
            phase = .signedOut
            userID = nil
            email = nil
            progress.reset()
            battles.reset()
            workouts.deactivate()
            NotificationService.shared.clearReminders()
            if wasSignedIn {
                onboarding.reset()
                AnalyticsService.reset()
                Task { await store.logOut() }
            }
            return
        }

        // A session arriving while signed out is a fresh Apple/Google flow;
        // one arriving while loading is the saved session restored at launch.
        let isFreshAuth = phase == .signedOut
        let wasAwaitingSignUp = onboarding.awaitingSignUp
        let isNewUser = userID != session.user.id
        if isNewUser {
            onboarding.beginSetupIfNeeded()
        }
        userID = session.user.id
        email = session.user.email
        phase = .signedIn
        if isNewUser {
            let id = session.user.id
            AnalyticsService.identify(
                userID: id,
                email: session.user.email,
                name: onboarding.trimmedName.isEmpty ? nil : onboarding.trimmedName
            )
            if isFreshAuth {
                let method = pendingAuthMethod ?? "unknown"
                pendingAuthMethod = nil
                if wasAwaitingSignUp {
                    AnalyticsService.trackSignUp(method: method)
                } else {
                    AnalyticsService.trackSignIn(method: method)
                }
            }
            Task { await store.logIn(userID: id) }
            Task { await bootstrap(userID: id) }
        }
    }

    /// Loads the account's data and recovers any workouts saved on this phone.
    private func bootstrap(userID: UUID) async {
        workouts.activate(userID: userID)
        await OnboardingSync.flushPending(userID: userID)
        await progress.load()
        try? await battles.load()
        await workouts.syncPending()
    }

    /// Saves the onboarding answers to the new account (called from the
    /// "setting everything up" screen after sign-up).
    func completeOnboardingSave() async {
        guard let userID else { return }
        let answers = onboarding.makeAnswers()
        AnalyticsService.setOnboardingProfile(
            mainGoal: answers.mainGoal,
            experience: answers.experience,
            gender: answers.gender,
            ageYears: answers.ageYears,
            workoutDaysPerWeek: answers.workoutDays.count,
            remindersRequested: answers.remindersRequested
        )
        await OnboardingSync.save(answers, userID: userID)
        await progress.load()
    }

    /// Foreground refresh: retries pending saves and reloads server state.
    func refresh() async {
        guard phase == .signedIn else { return }
        await store.refresh()
        await workouts.syncPending()
        await progress.load()
        try? await battles.load()
    }

    // MARK: - Apple (native only)

    /// Configures the native Sign in with Apple request with a hashed one-time nonce.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        print("[Auth] Starting Apple NATIVE sign in...")
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Runs the native Sign in with Apple sheet from a custom button.
    func signInWithApple() async {
        pendingAuthMethod = "apple"
        do {
            let authorization = try await appleController.signIn { request in
                prepareAppleRequest(request)
            }
            await completeAppleSignIn(.success(authorization))
        } catch {
            await completeAppleSignIn(.failure(error))
        }
    }

    /// Exchanges Apple's identity token with Supabase via `signInWithIdToken`.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            pendingAuthMethod = nil
            onboarding.awaitingSignUp = false
            if (error as? ASAuthorizationError)?.code == .canceled {
                print("[Auth] Apple NATIVE sign in canceled by user")
                return
            }
            print("[Auth] Apple NATIVE sign in failed: \(error.localizedDescription)")
            authError = "Apple sign-in didn't complete. Please try again."

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                pendingAuthMethod = nil
                print("[Auth] Apple NATIVE sign in returned no identity token")
                authError = "Apple didn't return a sign-in token. Please try again."
                return
            }
            guard let nonce = currentNonce else {
                pendingAuthMethod = nil
                print("[Auth] Apple NATIVE sign in missing nonce")
                authError = "Sign-in expired. Please try again."
                return
            }

            isAuthenticating = true
            defer { isAuthenticating = false }
            do {
                print("[Auth] Apple NATIVE identity token received; calling signInWithIdToken")
                if onboarding.trimmedName.isEmpty {
                    onboarding.name = credential.fullName?.givenName ?? ""
                }
                _ = try await Backend.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: nonce)
                )
                currentNonce = nil
                print("[Auth] Apple NATIVE sign in succeeded")

                // Apple only shares the name on the very first sign-in.
                let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !fullName.isEmpty {
                    try? await Backend.client.rpc("set_initial_display_name", params: NameParams(name: fullName)).execute()
                    await progress.load()
                }
            } catch {
                pendingAuthMethod = nil
                onboarding.awaitingSignUp = false
                print("[Auth] Apple NATIVE signInWithIdToken failed: \(error.localizedDescription)")
                authError = "Couldn't sign in with Apple. Check your connection and try again."
            }
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        pendingAuthMethod = "google"
        do {
            print("[Auth] Starting Google sign in (Supabase OAuth)...")
            try await Backend.client.auth.signInWithOAuth(provider: .google, redirectTo: Backend.authRedirectURL)
            print("[Auth] Google sign in succeeded")
        } catch {
            pendingAuthMethod = nil
            onboarding.awaitingSignUp = false
            let nsError = error as NSError
            if nsError.domain == ASWebAuthenticationSessionErrorDomain,
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                print("[Auth] Google sign in canceled by user")
                return
            }
            print("[Auth] Google sign in failed: \(error.localizedDescription)")
            authError = "Couldn't sign in with Google. Please try again."
        }
    }

    // MARK: - Sign out & delete

    func signOut() async {
        do {
            try await Backend.client.auth.signOut()
        } catch {
            print("[Auth] Remote sign out failed (local session cleared): \(error.localizedDescription)")
        }
    }

    /// Permanently deletes the account on the server, then clears the local session.
    func deleteAccount() async throws {
        do {
            try await Backend.client.functions.invoke("delete-account")
        } catch {
            print("[Auth] delete-account failed: \(error.localizedDescription)")
            throw error
        }
        if let userID {
            workouts.discardAll(for: userID)
        }
        try? await Backend.client.auth.signOut(scope: .local)
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard status == errSecSuccess else { continue }
            if Int(byte) < charset.count * (256 / charset.count) {
                result.append(charset[Int(byte) % charset.count])
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
