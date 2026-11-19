import SwiftUI

// MARK: - 01 Welcome

struct WelcomeScreen: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("onboarding_welcome_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
                    .scaleEffect(hasAppeared ? 1 : 1.06, anchor: .top)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.5),
                    .init(color: Theme.obNavyDeep.opacity(0.8), location: 0.74),
                    .init(color: Theme.obNavyDeep, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Pushcraft")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(
                            .linearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                    Text("Build strength. Craft your tower.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ivory.opacity(0.92))
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                }
                .padding(.top, 10)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : -12)

                Spacer()

                VStack(spacing: 6) {
                    OnboardingPrimaryButton(title: "Get started", action: onStart)
                    OnboardingSecondaryButton(title: "I already have an account", action: onSignIn)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { hasAppeared = true }
        }
    }
}

// MARK: - Sign-in buttons

/// Continue with Apple (native sheet) and Continue with Google.
struct AuthButtons: View {
    @Environment(AppState.self) private var appState
    var onStart: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Button {
                HapticService.ui.tap()
                onStart()
                Task { await appState.signInWithApple() }
            } label: {
                HStack(spacing: 10) {
                    Image("logo_apple")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Continue with Apple")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white, in: .rect(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Continue with Apple")

            Button {
                HapticService.ui.tap()
                onStart()
                Task { await appState.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image("logo_google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ivory)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.obCard, in: .rect(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Continue with Google")
        }
        .disabled(appState.isAuthenticating)
        .opacity(appState.isAuthenticating ? 0.55 : 1)
        .overlay {
            if appState.isAuthenticating {
                ProgressView().tint(Theme.amberSoft).controlSize(.large)
            }
        }
    }
}

// MARK: - Hidden reviewer login

private let reviewerTapLimit = 5
private let reviewerTapWindow: TimeInterval = 2

/// Screen title that reveals the reviewer email form after 5 quick taps.
struct ReviewerTitle: View {
    let text: String
    var onReveal: () -> Void

    @State private var tapCount = 0
    @State private var windowStart = Date.distantPast

    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .bold, design: .serif))
            .foregroundStyle(Theme.ivory)
            .contentShape(Rectangle())
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(windowStart) > reviewerTapWindow {
                    tapCount = 0
                }
                windowStart = now
                tapCount += 1
                if tapCount >= reviewerTapLimit {
                    tapCount = 0
                    HapticService.ui.warning()
                    onReveal()
                }
            }
    }
}

/// Hidden email + password sign-in for store reviewers (no device linking).
struct ReviewerEmailAuth: View {
    @Environment(AppState.self) private var appState

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 10) {
            reviewerField("Email", text: $email) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
            }
            reviewerField("Password", text: $password) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Button {
                submit()
            } label: {
                Group {
                    if appState.isAuthenticating {
                        ProgressView()
                            .tint(Theme.obNavy)
                    } else {
                        Text("Sign in")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.obNavy)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [Theme.amberSoft, Theme.amberDeep], startPoint: .top, endPoint: .bottom),
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(PressScaleStyle())
            .disabled(appState.isAuthenticating)
        }
        .opacity(appState.isAuthenticating ? 0.55 : 1)
    }

    private func reviewerField(_ placeholder: String, text: Binding<String>, @ViewBuilder field: () -> some View) -> some View {
        field()
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ivory)
            .submitLabel(.done)
            .onSubmit { submit() }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 20)
            .background(Theme.obCard, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.obCardBorder, lineWidth: 1)
            }
    }

    private func submit() {
        guard email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              password.isEmpty == false else { return }
        Task { await appState.signInWithEmail(email: email, password: password) }
    }
}

// MARK: - Existing account

struct ExistingAccountScreen: View {
    let model: OnboardingModel

    @State private var showReviewer = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            Image("golem")
                .resizable()
                .scaledToFit()
                .frame(height: 230)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                .accessibilityHidden(true)

            ReviewerTitle(text: "Welcome back") { showReviewer = true }
                .padding(.top, 18)

            Text("Sign in to keep building your towers.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .padding(.top, 6)

            if showReviewer {
                ReviewerEmailAuth()
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            AuthButtons()
            LegalLine()
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.25), value: showReviewer)
        .onAppear { model.awaitingSignUp = false }
    }
}

// MARK: - 02 Meet your guide

struct MeetGuideScreen: View {
    @State private var showGolem = false
    @State private var showBubble = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            if showBubble {
                SpeechBubble(text: "Welcome, builder. Every great tower starts with a foundation. Let's find yours.", fontSize: 20)
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 96)
            }

            Image("golem")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360, maxHeight: 360)
                .padding(.top, 22)
                .opacity(showGolem ? 1 : 0)
                .offset(y: showGolem ? 0 : 30)
                .shadow(color: Color(hex: 0x3E7BFF, opacity: 0.25), radius: 40)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Text("A few questions, then your first build.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .padding(.bottom, 100)
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { showGolem = true }
            try? await Task.sleep(for: .milliseconds(550))
            HapticService.ui.thud()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showBubble = true }
        }
    }
}
