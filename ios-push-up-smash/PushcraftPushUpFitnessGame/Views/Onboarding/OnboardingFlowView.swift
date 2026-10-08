import SwiftUI

/// Signed-out experience: Welcome → questionnaire → first build → sign up.
/// Pages slide between steps, but the Continue button stays pinned in place —
/// like switching tabs — and only disables until a page's answers are set.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState

    private var model: OnboardingModel { appState.onboarding }

    /// False while a story screen plays its staged reveal; those screens call
    /// back through `onCTAReady` when the button should fade in.
    @State private var ctaVisible = true

    private var showsTopBar: Bool {
        switch model.step {
        case .welcome, .introWorkout: false
        default: true
        }
    }

    /// Pages that crossfade instead of pushing.
    private var stepTransition: AnyTransition {
        switch model.step {
        case .journey, .howBuild: .opacity
        default: .push(from: model.isForward ? .trailing : .leading)
        }
    }

    /// The pinned call-to-action for the current step, if it has one.
    private var stepCTA: StepCTA? {
        switch model.step {
        case .meetGuide: StepCTA(title: "Let's begin")
        case .name: StepCTA(title: "Continue")
        case .mainGoal: StepCTA(title: "Continue", isEnabled: model.mainGoal != nil)
        case .experience: StepCTA(title: "Continue", isEnabled: model.experience != nil)
        case .gender: StepCTA(title: "Continue", isEnabled: model.gender != nil)
        case .age: StepCTA(title: "Continue")
        case .height: StepCTA(title: "Continue")
        case .frequency: StepCTA(title: "Continue", isEnabled: model.frequency != nil)
        case .boredom: StepCTA(title: "Continue", isEnabled: model.boredom != nil)
        case .equipment: StepCTA(title: "Continue", isEnabled: model.equipment != nil)
        case .seeingProgress: StepCTA(title: "Continue", isEnabled: model.seeingProgress != nil)
        case .journey: StepCTA(title: "Continue")
        case .howBuild: StepCTA(title: "Continue")
        case .pushupCapacity: StepCTA(title: "Continue", isEnabled: model.pushupCapacity != nil)
        case .workoutDays: StepCTA(title: "Continue", isEnabled: !model.workoutDays.isEmpty)
        case .reminder:
            StepCTA(
                title: model.reminderPrimaryTitle,
                isLoading: model.isRequestingNotifications,
                secondaryTitle: "Not now"
            )
        case .firstBuild: StepCTA(title: "I'm ready")
        case .phoneSetup: StepCTA(title: "Next")
        case .pushupForm: StepCTA(title: "Next")
        case .detectionTips: StepCTA(title: "Start", secondaryTitle: "I can't do push-ups right now")
        case .firstReward: StepCTA(title: "Continue")
        case .forecast: StepCTA(title: "Continue")
        case .welcome, .signIn, .introWorkout, .saveProgress: nil
        }
    }

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            OnboardingBackground()

            screen(for: model.step)
                .id(model.step)
                .transition(stepTransition)
                .safeAreaPadding(.top, showsTopBar ? 50 : 0)

            if showsTopBar {
                OnboardingTopBar(progress: model.step.progress, canGoBack: model.canGoBack) {
                    model.back()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let cta = stepCTA {
                PersistentCTA(
                    title: cta.title,
                    isEnabled: cta.isEnabled,
                    isLoading: cta.isLoading,
                    secondaryTitle: cta.secondaryTitle,
                    onPrimary: primaryTapped,
                    onSecondary: secondaryTapped
                )
                .opacity(ctaVisible ? 1 : 0)
                .allowsHitTesting(ctaVisible)
                .animation(.easeInOut(duration: 0.35), value: ctaVisible)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsTopBar)
        .onChange(of: model.step) { _, step in
            switch step {
            case .journey, .howBuild:
                ctaVisible = false
            default:
                ctaVisible = true
            }
        }
        .onAppear {
            // The flow starts here (no advance() leads to Welcome), so the
            // funnel's first event fires when a signed-out visitor arrives.
            if model.step == .welcome {
                AnalyticsService.trackOnboardingStarted()
                AnalyticsService.trackOnboardingStep(
                    name: model.step.analyticsName,
                    order: model.step.analyticsOrder
                )
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "Sign in",
            isPresented: Binding(get: { appState.authError != nil }, set: { if !$0 { appState.authError = nil } })
        ) {
            Button("OK", role: .cancel) { appState.authError = nil }
        } message: {
            Text(appState.authError ?? "")
        }
    }

    // MARK: - Actions

    private func primaryTapped() {
        switch model.step {
        case .meetGuide: model.advance(to: .name)
        case .name: model.advance(to: .mainGoal)
        case .mainGoal: model.advance(to: .experience)
        case .experience: model.advance(to: .gender)
        case .gender: model.advance(to: .age)
        case .age:
            model.hasConfirmedAge = true
            model.advance(to: .height)
        case .height:
            model.hasConfirmedHeight = true
            model.advance(to: .frequency)
        case .frequency: model.advance(to: .boredom)
        case .boredom: model.advance(to: .equipment)
        case .equipment: model.advance(to: .seeingProgress)
        case .seeingProgress: model.advance(to: .journey)
        case .journey: model.advance(to: .howBuild)
        case .howBuild: model.advance(to: .pushupCapacity)
        case .pushupCapacity: model.advance(to: .workoutDays)
        case .workoutDays: model.advance(to: .reminder)
        case .reminder:
            Task { await model.handleReminderPrimaryTap() }
        case .firstBuild: model.advance(to: .phoneSetup)
        case .phoneSetup: model.advance(to: .pushupForm)
        case .pushupForm: model.advance(to: .detectionTips)
        case .detectionTips:
            print("[Onboarding] Start tapped — advancing to the intro workout")
            model.advance(to: .introWorkout)
        case .firstReward: model.advance(to: .forecast)
        case .forecast: model.advance(to: .saveProgress)
        default: break
        }
    }

    private func secondaryTapped() {
        switch model.step {
        case .reminder: model.skipReminders()
        case .detectionTips: model.advance(to: .forecast)
        default: break
        }
    }

    // MARK: - Screens

    @ViewBuilder
    private func screen(for step: OnboardingStep) -> some View {
        @Bindable var model = model

        switch step {
        case .welcome:
            WelcomeScreen(onStart: { model.advance(to: .meetGuide) }, onSignIn: { model.advance(to: .signIn) })
        case .signIn:
            ExistingAccountScreen(model: model)
        case .meetGuide:
            MeetGuideScreen()
        case .name:
            NameScreen(model: model)
        case .mainGoal:
            SingleChoiceScreen(title: "What brings you to PushcraftPushUpFitnessGame?", selection: $model.mainGoal)
        case .experience:
            SingleChoiceScreen(title: "How experienced are you with exercise?", selection: $model.experience)
        case .gender:
            SingleChoiceScreen(
                title: "What's your gender?",
                helper: "This helps us personalize your experience.",
                selection: $model.gender
            )
        case .age:
            AgeScreen(model: model)
        case .height:
            HeightScreen(model: model)
        case .frequency:
            SingleChoiceScreen(
                title: "How often do you exercise now?",
                helper: "Think about a typical week.",
                selection: $model.frequency
            )
        case .boredom:
            StatementScreen(
                title: "Does this sound like you?",
                statement: "I start motivated, but ordinary workouts get boring.",
                selection: $model.boredom
            )
        case .equipment:
            StatementScreen(
                title: "Does this get in your way?",
                statement: "Getting to a gym or finding equipment makes exercise harder to fit in.",
                selection: $model.equipment
            )
        case .seeingProgress:
            StatementScreen(
                title: "What about this?",
                statement: "It's harder to stay consistent when I can't see my progress.",
                selection: $model.seeingProgress
            )
        case .journey:
            TowerJourneyScreen(onCTAReady: { ctaVisible = true })
        case .howBuild:
            HowBuildScreen(onCTAReady: { ctaVisible = true })
        case .pushupCapacity:
            SingleChoiceScreen(
                title: "How many push-ups can you comfortably do in one set?",
                helper: "An estimate is fine. You don't need to test your maximum.",
                selection: $model.pushupCapacity
            )
        case .workoutDays:
            WorkoutDaysScreen(model: model)
        case .reminder:
            ReminderScreen(model: model)
        case .firstBuild:
            FirstBuildScreen(model: model)
        case .phoneSetup:
            InstructionScreen(
                title: "Set up your phone",
                body1: "Place your phone securely on the floor with the camera facing you.",
                body2: "Use a clear, well-lit space where you have room to move.",
                imageName: "onboarding_setup_phone",
                imageAspect: 1594 / 987
            )
        case .pushupForm:
            InstructionScreen(
                title: "Get into position",
                body1: "Place your entire body in the frame and begin doing push-ups. The video won't leave your device.",
                imageName: "onboarding_pushup_movement"
            )
        case .detectionTips:
            DetectionTipsScreen()
        case .introWorkout:
            IntroWorkoutScreen(
                onFinish: { reps in model.finishIntro(reps: reps) },
                onSkip: { model.advance(to: .forecast) }
            )
        case .firstReward:
            FirstRewardScreen(model: model)
        case .forecast:
            ForecastScreen(model: model)
        case .saveProgress:
            SaveProgressScreen(model: model)
        }
    }
}

/// The pinned call-to-action for one step.
private struct StepCTA {
    var title: String
    var isEnabled = true
    var isLoading = false
    var secondaryTitle: String?
}
