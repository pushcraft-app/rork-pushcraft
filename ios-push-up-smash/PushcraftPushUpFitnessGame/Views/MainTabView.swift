import SwiftUI

/// PushcraftPushUpFitnessGame's main navigation: Home, Towers, Battles, Profile.
/// Each tab uses custom selected/unselected artwork that swaps with the
/// selection state. On iOS 26 the system tab bar renders as Liquid Glass.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(data: appState.progress.homeData)
            }
            .tabItem { tabItem(for: .home) }
            .tag(AppTab.home)

            NavigationStack {
                TowersView()
            }
            .tabItem { tabItem(for: .towers) }
            .tag(AppTab.towers)

            BattlesView()
                .tabItem { tabItem(for: .battles) }
            .tag(AppTab.battles)

            NavigationStack {
                ProfileView()
            }
            .tabItem { tabItem(for: .profile) }
            .tag(AppTab.profile)
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
        .onChange(of: selection) { _, _ in
            HapticService.ui.tap()
        }
    }

    private func tabItem(for tab: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(selection == tab ? tab.activeIconName : tab.iconName)
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
