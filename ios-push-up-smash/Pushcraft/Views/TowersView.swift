import SwiftUI

/// The Towers tab: browse completed towers, continue the current one, and
/// preview what's locked ahead.
struct TowersView: View {
    @Environment(AppState.self) private var appState
    @State private var centeredTowerID: String?
    @State private var showUnlockAlert = false
    @State private var unlockMessage = ""
    @State private var showWorkoutPrep = false

    private var towers: [Tower] { appState.progress.towers }
    private var home: HomeData { appState.progress.homeData }
    private var currentTowerID: String? {
        towers.first { $0.status == .inProgress }?.id ?? towers.last { $0.status == .completed }?.id
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(250, geo.size.width * 0.62)
            let carouselInset = (geo.size.width - cardWidth) / 2

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    carousel(cardWidth: cardWidth, inset: carouselInset)
                        .padding(.top, 10)

                    divider
                        .padding(.top, 26)

                    milestoneSection
                        .padding(.top, 22)

                    continueButton
                        .padding(.top, 20)
                }
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await appState.refresh() }
        }
        .background(Theme.towersNavy.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showWorkoutPrep) {
            WorkoutPrepView()
        }
        .alert("Tower locked", isPresented: $showUnlockAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(unlockMessage)
        }
        .onAppear {
            if centeredTowerID == nil {
                centeredTowerID = currentTowerID
            }
        }
        .onChange(of: currentTowerID) { _, newValue in
            if centeredTowerID == nil { centeredTowerID = newValue }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            CountersRow(
                streak: home.streak,
                xp: home.xp,
                coinsDisplay: home.coinsDisplay
            )

            Text("Towers")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .padding(.top, 14)

            Text("One rep. One block higher.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carousel

    private func carousel(cardWidth: CGFloat, inset: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(towers) { tower in
                    TowerCardView(
                        tower: tower,
                        isCentered: centeredTowerID == tower.id,
                        onLockedTap: { showLockedMessage(for: tower) }
                    )
                    .frame(width: cardWidth)
                    .scaleEffect(centeredTowerID == tower.id ? 1 : 0.9)
                    .opacity(centeredTowerID == tower.id ? 1 : 0.7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: centeredTowerID)
                }

                ComingSoonCard()
                    .frame(width: cardWidth)
                    .id("coming-soon")
                    .scaleEffect(centeredTowerID == "coming-soon" ? 1 : 0.9)
                    .opacity(centeredTowerID == "coming-soon" ? 1 : 0.7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: centeredTowerID)
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, inset, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredTowerID, anchor: .center)
        .frame(height: 430)
    }

    private func showLockedMessage(for tower: Tower) {
        unlockMessage = "Complete \(tower.unlockedAfter ?? "the previous tower") to unlock \(tower.name)."
        showUnlockAlert = true
    }

    // MARK: - Milestone

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private var milestoneSection: some View {
        VStack(spacing: 6) {
            Text("Your next milestone")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ivory)
            Text(milestoneText)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var milestoneText: String {
        if home.isAllComplete { return "Every tower is built. Your reps still count toward your stats." }
        return "\(home.repsToGo) reps to finish Stage \(home.stageNumber) · \(home.stageName)."
    }

    // MARK: - Continue building

    private var continueButton: some View {
        Button {
            showWorkoutPrep = true
        } label: {
            HStack(spacing: 10) {
                Text("Continue building")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Color(hex: 0x3A2200))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                .linearGradient(
                    colors: [Theme.amberSoft, Theme.amberDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Theme.amberDeep.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack { TowersView() }
        .environment(AppState())
}

/// Teaser card at the end of the carousel: more towers are on the way.
private struct ComingSoonCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.amberSoft.opacity(0.85))
                .shadow(color: .black.opacity(0.4), radius: 4)

            Text("Coming soon")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory.opacity(0.9))

            Text("More towers on the way")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.panel.opacity(0.45),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}
