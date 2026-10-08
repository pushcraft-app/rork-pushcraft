//
//  PushcraftPushUpFitnessGameApp.swift
//  PushcraftPushUpFitnessGame
//
//  Created by Rork on September 30, 2026.
//

import RevenueCat
import Supabase
import SwiftUI

@main
struct PushcraftPushUpFitnessGameApp: App {
    @State private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
        AnalyticsService.configure()
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.start()
                    AnalyticsService.trackAppOpen()
                }
                .onOpenURL { url in
                    Backend.client.auth.handle(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await appState.refresh() }
                    }
                }
        }
    }
}
