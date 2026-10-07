import SwiftUI

/// The Home tab: what the user is building, current stage progress,
/// and the next workout to start.
struct HomeView: View {
    let data: HomeData

    @Environment(AppState.self) private var appState

    @State private var showWorkoutPrep = false
    @State private var showJourney = false
    @State private var headerHeight: CGFloat = 96

    private let topInset: CGFloat = 8
    private let pillGap: CGFloat = 14
    private let pillHeight: CGFloat = 26
    private let towerHeight: CGFloat = 400
    /// Fraction of the tower image height where the content panel begins (mid-foundation).
    private let panelStartFraction: CGFloat = 0.63

    var body: some View {
        ZStack(alignment: .top) {
            towerLayer

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newValue in
                            headerHeight = newValue
                        }

                    Color.clear
                        .frame(height: pillGap + pillHeight + towerHeight * panelStartFraction)
                        .allowsHitTesting(false)

                    contentPanel
                }
                .padding(.top, topInset)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await appState.refresh() }
        }
        .background {
            background
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showWorkoutPrep) {
            WorkoutPrepView()
        }
        .navigationDestination(isPresented: $showJourney) {
            JourneyView(data: data)
        }
    }

    // MARK: - Background

    private var background: some View {
        Theme.night
            .overlay {
                Image("fantasy_castle_night_bg")
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            }
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.4), location: 0),
                        .init(color: .black.opacity(0.05), location: 0.22),
                        .init(color: .black.opacity(0.1), location: 0.62),
                        .init(color: Theme.night.opacity(0.85), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            counters
            headline
        }
    }

    // MARK: - Counters

    private var counters: some View {
        CountersRow(streak: data.streak, xp: data.xp, coinsDisplay: data.coinsDisplay)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Build strength.")
            Text("Craft your tower.")
        }
        .font(.system(size: 26, weight: .bold, design: .serif))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Theme.ivory)
        .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
    }

    // MARK: - Tower (fixed, does not scroll)

    /// The tower being built right now: in progress, or the last one completed.
    private var currentTower: Tower? {
        let towers = appState.progress.towers
        return towers.first { $0.status == .inProgress } ?? towers.last { $0.status == .completed }
    }

    private var towerLayer: some View {
        VStack(spacing: 0) {
            Text("YOUR CURRENT TOWER")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.ivory.opacity(0.95))
                .padding(.horizontal, 12)
                .frame(height: pillHeight)
                .background(Theme.pillFill, in: .capsule)
                .overlay { Capsule().strokeBorder(Theme.pillBorder, lineWidth: 1) }
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)

            TowerConstructionView(
                towerID: currentTower?.id ?? data.towerName,
                builtStages: currentTower?.builtStages ?? 0,
                stageFraction: currentTower?.stageFraction ?? 0
            )
            .frame(height: towerHeight)
            .shadow(color: .black.opacity(0.45), radius: 26, y: 12)
        }
        .padding(.top, topInset + headerHeight + pillGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Content (scrolls over the tower)

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressSection
                .padding(.top, 22)
                .background {
                    progressScrim
                        .padding(.vertical, -56)
                        .padding(.horizontal, -20)
                }

            if appState.workouts.unsyncedCount > 0 {
                syncBanner
                    .padding(.top, 12)
            }

            UpNextCard(data: data)
                .padding(.top, 12)

            startButton
                .padding(.top, 16)

            journeyLink
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    /// Soft atmospheric fog behind the stage-progress text. The navy is sampled
    /// from the background artwork (Theme.panelTint); the gradient fades to fully
    /// transparent above and below so no panel edge is visible over the art.
    private var progressScrim: some View {
        let navy = Theme.panelTint
        return LinearGradient(
            stops: [
                .init(color: navy.opacity(0), location: 0),
                .init(color: navy.opacity(0.15), location: 0.22),
                .init(color: navy.opacity(0.65), location: 0.5),
                .init(color: navy.opacity(0.45), location: 0.74),
                .init(color: navy.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Stage progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.towerName)
                .font(.system(size: 29, weight: .bold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Theme.ivory)
                .shadow(color: .black.opacity(0.55), radius: 6, y: 2)

            Text("Stage \(data.stageNumber) of \(data.totalStages) · \(data.stageName)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.mist)

            HStack(spacing: 12) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.16))
                        Capsule()
                            .fill(
                                .linearGradient(
                                    colors: [Theme.progressCyan, Color(hex: 0x7BE9FF)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * data.stageProgress, 14))
                            .shadow(color: Theme.progressCyan.opacity(0.8), radius: 6)
                    }
                }
                .frame(height: 13)

                Text("\(data.stagePercent)%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.progressCyan)
            }

            Text(data.isAllComplete
                 ? "Every tower built — bonus reps still count"
                 : "\(data.repsIntoStage) of \(data.stageTarget) reps · \(data.repsToGo) to go")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.mist)
        }
    }

    private var syncBanner: some View {
        let count = appState.workouts.unsyncedCount
        return HStack(spacing: 10) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.amberSoft)
            Text(count == 1 ? "1 workout waiting to sync" : "\(count) workouts waiting to sync")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ivory)
            Spacer(minLength: 8)
            Button {
                Task { await appState.refresh() }
            } label: {
                Text(appState.workouts.isSyncing ? "Syncing…" : "Sync now")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.amberSoft)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(appState.workouts.isSyncing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.cardFill, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.amberSoft.opacity(0.45), lineWidth: 1)
        }
    }

    // MARK: - Actions

    private var startButton: some View {
        Button {
            showWorkoutPrep = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 19, weight: .bold))
                Text("Start Workout")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: 0x3A2200))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                .linearGradient(
                    colors: [Theme.amberSoft, Theme.amberDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Theme.amberDeep.opacity(0.5), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleStyle())
    }

    private var journeyLink: some View {
        Button {
            showJourney = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "signpost.right.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("View journey")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.ivory.opacity(0.92))
            .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PressScaleStyle())
    }
}

#Preview {
    NavigationStack { HomeView(data: .mock) }
        .environment(AppState())
}
