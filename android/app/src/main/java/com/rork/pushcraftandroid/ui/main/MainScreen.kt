package com.rork.pushcraftandroid.ui.main

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.model.ActiveSession
import com.rork.pushcraftandroid.ui.battles.BattleDetailsScreen
import com.rork.pushcraftandroid.ui.battles.BattleResultScreen
import com.rork.pushcraftandroid.ui.battles.BattlesScreen
import com.rork.pushcraftandroid.ui.profile.ProfileScreen
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.workout.WorkoutFlowScreen

enum class AppTab(val route: String, val title: String, val icon: Int, val activeIcon: Int) {
    Home("home", "Home", R.drawable.tab_home, R.drawable.tab_home_active),
    Towers("towers", "Towers", R.drawable.tab_towers, R.drawable.tab_towers_active),
    Battles("battles", "Battles", R.drawable.tab_battles, R.drawable.tab_battles_active),
    Profile("profile", "Profile", R.drawable.tab_profile, R.drawable.tab_profile_active)
}

/** Holds the workout currently shown full-screen (start → arena → result). */
class WorkoutHost {
    var session by mutableStateOf<ActiveSession?>(null)
}

/** Pushcraft's main navigation: four tabs plus pushed detail screens. */
@Composable
fun MainScreen(appState: AppState) {
    val nav = rememberNavController()
    val host = remember { WorkoutHost() }
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val showBar = AppTab.entries.any { it.route == route }

    Box(Modifier.fillMaxSize().background(Pc.night)) {
        Scaffold(
            containerColor = Pc.night,
            bottomBar = {
                if (showBar) {
                    NavigationBar(containerColor = Color(0xF2091224), tonalElevation = 0.dp) {
                        AppTab.entries.forEach { tab ->
                            val selected = route == tab.route
                            NavigationBarItem(
                                selected = selected,
                                onClick = {
                                    if (!selected) {
                                        Haptics.tap()
                                        nav.navigate(tab.route) {
                                            popUpTo(AppTab.Home.route) { saveState = true }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    }
                                },
                                icon = { Image(painterResource(if (selected) tab.activeIcon else tab.icon), null, Modifier.size(26.dp)) },
                                label = { Text(tab.title, style = rounded(11, FontWeight.SemiBold)) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedTextColor = Pc.amber, unselectedTextColor = Pc.mist, indicatorColor = Color.Transparent
                                )
                            )
                        }
                    }
                }
            }
        ) { padding ->
            NavHost(
                nav, startDestination = AppTab.Home.route,
                modifier = Modifier.fillMaxSize(),
                enterTransition = { slideInHorizontally { it } + fadeIn() },
                exitTransition = { slideOutHorizontally { -it / 4 } + fadeOut() },
                popEnterTransition = { slideInHorizontally { -it / 4 } + fadeIn() },
                popExitTransition = { slideOutHorizontally { it } + fadeOut() }
            ) {
                tab(AppTab.Home) { HomeScreen(appState, nav, Modifier.padding(bottom = padding.calculateBottomPadding())) }
                tab(AppTab.Towers) { TowersScreen(appState, nav, Modifier.padding(bottom = padding.calculateBottomPadding())) }
                tab(AppTab.Battles) { BattlesScreen(appState, nav, Modifier.padding(bottom = padding.calculateBottomPadding())) }
                tab(AppTab.Profile) { ProfileScreen(appState, Modifier.padding(bottom = padding.calculateBottomPadding())) }
                composable(
                    "trail",
                    enterTransition = { scaleIn(initialScale = 0.85f) + fadeIn() },
                    popExitTransition = { scaleOut(targetScale = 0.85f) + fadeOut() }
                ) { TowerTrailScreen(appState, nav) }
                composable("journey/{tower}", arguments = listOf(navArgument("tower") { type = NavType.StringType })) {
                    JourneyScreen(appState, it.arguments?.getString("tower"), nav)
                }
                composable("prep") { WorkoutPrepScreen(appState, nav, host) }
                composable("battle/{id}") { BattleDetailsScreen(appState, it.arguments?.getString("id").orEmpty(), nav, host) }
                composable("battleResult/{id}") { BattleResultScreen(appState, it.arguments?.getString("id").orEmpty(), nav) }
            }
        }
        host.session?.let { session ->
            WorkoutFlowScreen(session, appState) { host.session = null }
        }
    }
}

private fun androidx.navigation.NavGraphBuilder.tab(tab: AppTab, content: @Composable () -> Unit) {
    composable(tab.route, enterTransition = { fadeIn() }, exitTransition = { fadeOut() }, popEnterTransition = { fadeIn() }, popExitTransition = { fadeOut() }) { content() }
}

@Suppress("unused")
private fun NavHostController.safePop() = popBackStack()
