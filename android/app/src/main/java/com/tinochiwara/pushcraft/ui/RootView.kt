package com.tinochiwara.pushcraft.ui

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.StoreService
import com.tinochiwara.pushcraft.ui.main.MainScreen
import com.tinochiwara.pushcraft.ui.onboarding.OnboardingBackground
import com.tinochiwara.pushcraft.ui.onboarding.OnboardingFlow
import com.tinochiwara.pushcraft.ui.onboarding.PaywallScreen
import com.tinochiwara.pushcraft.ui.onboarding.SetupProgressScreen
import com.tinochiwara.pushcraft.ui.theme.Pc

private enum class RootScreen { Loading, Onboarding, Setup, Paywall, App }

/** Routes between loading, onboarding, setup, paywall and the main app. */
@Composable
fun RootView(appState: AppState) {
    val phase by appState.phase.collectAsState()
    val store by appState.store.state.collectAsState()
    val screen = when (phase) {
        AppState.Phase.Loading -> RootScreen.Loading
        AppState.Phase.SignedOut -> RootScreen.Onboarding
        AppState.Phase.SignedIn -> when {
            appState.onboarding.isSettingUp -> RootScreen.Setup
            store.access == StoreService.Access.Unknown -> RootScreen.Loading
            store.access == StoreService.Access.None -> RootScreen.Paywall
            else -> RootScreen.App
        }
    }
    Crossfade(screen, animationSpec = tween(300), label = "root") { s ->
        when (s) {
            RootScreen.Loading -> Box(Modifier.fillMaxSize()) {
                OnboardingBackground()
                CircularProgressIndicator(Modifier.align(Alignment.Center), color = Pc.amberSoft)
            }
            RootScreen.Onboarding -> OnboardingFlow(appState)
            RootScreen.Setup -> SetupProgressScreen(appState)
            RootScreen.Paywall -> PaywallScreen(appState)
            RootScreen.App -> MainScreen(appState)
        }
    }
}
