import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    private enum Screen: Equatable {
        case loading, onboarding, setup, paywall, app
    }

    private var screen: Screen {
        switch appState.phase {
        case .loading:
            return .loading
        case .signedOut:
            return .onboarding
        case .signedIn:
            if appState.onboarding.isSettingUp { return .setup }
            switch appState.store.access {
            case .unknown: return .loading
            case .none: return .paywall
            case .premium: return .app
            }
        }
    }

    var body: some View {
        Group {
            switch screen {
            case .loading:
                ZStack {
                    OnboardingBackground()
                    ProgressView().tint(Theme.amberSoft).controlSize(.large)
                }
            case .onboarding:
                OnboardingFlowView()
            case .setup:
                SetupProgressView()
            case .paywall:
                PaywallView()
            case .app:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
