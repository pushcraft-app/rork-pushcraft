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

// MARK: - Existing account

struct ExistingAccountScreen: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            Image("golem")
                .resizable()
                .scaledToFit()
                .frame(height: 230)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                .accessibilityHidden(true)

            Text("Welcome back")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .padding(.top, 18)

            Text("Sign in to keep building your towers.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .padding(.top, 6)

            Spacer()

            AuthButtons()
            LegalLine()
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
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
