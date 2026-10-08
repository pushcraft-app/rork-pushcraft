import SwiftUI

/// The Profile tab: avatar, display name and lifetime stats from the server,
/// with a gear that opens the Settings sheet.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showEditProfile = false

    private var progress: ProgressStore { appState.progress }
    private var stats: StatsDTO? { progress.stats }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                profileSection
                    .padding(.top, 20)

                statsSection
                    .padding(.top, 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await appState.refresh() }
        .background(Theme.towersNavy.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
                .environment(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Profile")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xAFC3E8))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(spacing: 12) {
            Button {
                showEditProfile = true
            } label: {
                avatar
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Edit profile")
            .padding(.top, 8)

            Text(progress.displayName.isEmpty ? " " : progress.displayName)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        Group {
            if let data = progress.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            .linearGradient(
                                colors: [Color(hex: 0x33456B), Color(hex: 0x1C2A47)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Image(systemName: "person.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(Theme.mist)
                }
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(.circle)
        .overlay {
            Circle()
                .strokeBorder(Theme.amberSoft, lineWidth: 3)
                .shadow(color: Theme.amber.opacity(0.35), radius: 10)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your stats")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ivory)

            ProfileStatCard(
                value: String(stats?.totalReps ?? 0),
                label: "Total Reps"
            ) {
                Image("stat_dumbbell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }

            HStack(spacing: 12) {
                ProfileStatCard(value: "\(stats?.completedWorkouts ?? 0)", label: "Completed sessions") {
                    Image("stat_calendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                ProfileStatCard(value: "\(stats?.completedTowers ?? 0)", label: "Completed towers") {
                    Image("stat_tower")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
            }

            HStack(spacing: 12) {
                ProfileStatCard(value: "\(progress.displayStreak)", label: "Current streak") {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Theme.amberSoft, Color(hex: 0xFF6B1E)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                ProfileStatCard(
                    value: String(stats?.coinsBalance ?? 0),
                    label: "Coins",
                    valueColor: Theme.gold
                ) {
                    Image("gold_coin_star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Navy stat card in the reference style: icon, divider, prominent value over
/// a smaller label. Display-only.
struct ProfileStatCard<Icon: View>: View {
    let value: String
    let label: String
    var valueColor: Color = Theme.ivory
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 14) {
            icon()
                .frame(width: 34)
                .frame(minHeight: 34)

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .battleCardStyle()
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
}
