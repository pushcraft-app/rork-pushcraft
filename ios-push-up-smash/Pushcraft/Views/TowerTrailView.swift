import SwiftUI

/// The Tower Trail: a scrollable fantasy map between Home and the journey
/// timeline. The user's towers stand on floating islands linked by stone
/// bridges — tapping an unlocked tower opens that tower's journey.
struct TowerTrailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showJourney = false
    @State private var journeyTowerID: String?
    /// Tower currently showing its unlock hint bubble.
    @State private var hintTowerID: String?
    /// Animates 0 → 1 on a locked tap, driving the shake via `ShakeEffect`.
    @State private var shakeProgress: CGFloat = 0
    @State private var glowPulse = false
    @State private var hintTask: Task<Void, Never>?

    private var towers: [Tower] { appState.progress.towers }

    private var currentTowerID: String? {
        towers.first { $0.status == .inProgress }?.id
            ?? towers.last { $0.status == .completed }?.id
    }

    /// Island anchors on the trail painting, first tower at the bottom.
    /// Fraction of the map image (not the scroll canvas).
    private static let islandSlots: [(x: CGFloat, y: CGFloat)] = [
        (0.38, 0.705), // Oakspire — lowest island, bottom left
        (0.62, 0.585), // Stonewatch — island above right
        (0.36, 0.475), // Frostkeep — mid-left island
        (0.64, 0.360), // Emberhold — island above right
        (0.42, 0.275)  // Skyward Spire — summit island
    ]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height * 1.7

            ZStack(alignment: .topLeading) {
                ScrollView(showsIndicators: false) {
                    scene(width: width, height: height)
                }
                .scrollBounceBehavior(.always)

                backButton
                    .padding(.leading, 20)
                    .padding(.top, 6)
            }
        }
        .background(Theme.night.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showJourney) {
            if let journeyTowerID {
                JourneyView(data: appState.progress.homeData(towerID: journeyTowerID))
            }
        }
        .onAppear { glowPulse = true }
        .onDisappear { hintTask?.cancel() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Scene

    private func scene(width: CGFloat, height: CGFloat) -> some View {
        // Cloud sky covers the whole canvas; the islands painting renders
        // zoomed-in (1.25× screen width) and centered so towers read large,
        // with the edge islands kept clear of the screen edges.
        let zoom: CGFloat = 1.25
        let mapWidth = width * zoom
        let mapHeight = mapWidth * 1.5
        let mapX = (width - mapWidth) / 2
        let skyPad = max(0, (height - mapHeight) / 2)

        return ZStack(alignment: .topLeading) {
            cloudSky(width: width, height: height)

            mapImage(width: mapWidth, height: mapHeight)
                .offset(x: mapX, y: skyPad)

            ForEach(Array(towers.enumerated()), id: \.element.id) { index, tower in
                let slot = Self.islandSlots[min(index, Self.islandSlots.count - 1)]
                TrailNode(
                    tower: tower,
                    isCurrent: tower.id == currentTowerID,
                    width: width * (tower.id == currentTowerID ? 0.36 : 0.30),
                    glowPulse: glowPulse,
                    isShaking: hintTowerID == tower.id,
                    shakeProgress: shakeProgress,
                    showsHint: hintTowerID == tower.id,
                    onTap: { handleTap(tower) }
                )
                .position(x: mapX + mapWidth * slot.x, y: skyPad + mapHeight * slot.y)
            }
        }
        .frame(width: width, height: height)
    }

    /// Sharp cloud painting filling the entire screen behind the map, so
    /// push/pull bounce always reveals real clouds — no blur bands.
    private func cloudSky(width: CGFloat, height: CGFloat) -> some View {
        Image("sky_clouds_background")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    /// The trail painting at its exact 2:3 aspect so nothing is stretched.
    private func mapImage(width: CGFloat, height: CGFloat) -> some View {
        Image("floating_islands_trail_map")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    // MARK: - Actions

    private func handleTap(_ tower: Tower) {
        guard tower.status != .locked else {
            HapticService.ui.warning()
            hintTask?.cancel()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                hintTowerID = tower.id
            }
            shakeProgress = 0
            withAnimation(.linear(duration: 0.55)) {
                shakeProgress = 1
            }
            hintTask = Task {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    if hintTowerID == tower.id { hintTowerID = nil }
                }
            }
            return
        }

        HapticService.ui.tap()
        withAnimation(.easeOut(duration: 0.2)) { hintTowerID = nil }
        journeyTowerID = tower.id
        showJourney = true
    }

    // MARK: - Back button

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ivory)
                .frame(width: 44, height: 44)
                .background(Theme.panel, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Back")
    }
}

// MARK: - Trail node

/// One tower on the trail: its live construction art, name plaque, status
/// badges, and (for the current tower) a pulsing golden glow.
private struct TrailNode: View {
    let tower: Tower
    let isCurrent: Bool
    let width: CGFloat
    let glowPulse: Bool
    let isShaking: Bool
    let shakeProgress: CGFloat
    let showsHint: Bool
    let onTap: () -> Void

    private var isLocked: Bool { tower.status == .locked }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack {
                    if isCurrent {
                        glow
                    }
                    if isLocked {
                        lockedHalo
                    }

                    TowerConstructionView(
                        towerID: tower.id,
                        builtStages: tower.builtStages,
                        stageFraction: tower.stageFraction,
                        isLocked: isLocked
                    )
                    .frame(height: width * 1.5)

                    if tower.status == .completed {
                        badge(symbol: "checkmark", fill: Theme.amberSoft, symbolColor: Color(hex: 0x3A2200))
                    }
                }

                if isCurrent {
                    youAreHerePlaque
                } else if !isLocked {
                    namePlate
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .modifier(ShakeEffect(amount: width * 0.06, animatableData: isShaking ? shakeProgress : 0))
        .overlay(alignment: .top) {
            if showsHint {
                hintBubble
                    .offset(y: -(width * 0.55))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isLocked ? "Locked" : "Opens the journey for \(tower.name)")
    }

    private var accessibilityText: String {
        switch tower.status {
        case .completed: "\(tower.name), completed tower"
        case .inProgress: "\(tower.name), current tower, \(tower.percentComplete) percent built"
        case .locked: "\(tower.name), locked"
        }
    }

    /// Pulsing golden halo behind the current tower.
    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.amberSoft.opacity(0.55), Theme.amberSoft.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.625
                )
            )
            .frame(width: width * 1.25, height: width * 1.25)
            .scaleEffect(glowPulse ? 1.1 : 0.92)
            .opacity(glowPulse ? 1 : 0.65)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)
    }

    /// Soft navy halo behind a locked tower so its dashed ivory silhouette
    /// stays readable against the bright sky.
    private var lockedHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0x14224A).opacity(0.4), Color(hex: 0x14224A).opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.7
                )
            )
            .frame(width: width * 1.4, height: width * 1.4)
    }

    private func badge(symbol: String, fill: Color, symbolColor: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(symbolColor)
            .frame(width: 28, height: 28)
            .background(fill, in: .circle)
            .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5) }
            .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            .offset(x: width * 0.38, y: -width * 0.18)
    }

    /// Gold "YOU'RE HERE" ribbon over a navy name plate, matching the
    /// onboarding START HERE banner style.
    private var youAreHerePlaque: some View {
        VStack(spacing: -4) {
            Text("YOU'RE HERE")
                .font(.system(size: 11, weight: .heavy, design: .serif))
                .tracking(0.8)
                .foregroundStyle(Color(hex: 0x2A1A06))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    .linearGradient(colors: [Color(hex: 0xFFD98A), Color(hex: 0xE2A23A)], startPoint: .top, endPoint: .bottom),
                    in: .capsule
                )
                .zIndex(1)

            Text(tower.name)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 14)
                .padding(.top, 9)
                .padding(.bottom, 6)
                .frame(width: max(width * 0.8, 110))
                .background(Color(hex: 0x14244A), in: .rect(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            .linearGradient(colors: [Color(hex: 0xFFD98A), Color(hex: 0xB37A22)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5
                        )
                }
        }
        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }

    private var namePlate: some View {
        Text(tower.name)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(isLocked ? Theme.mist.opacity(0.7) : Theme.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(hex: 0x14244A).opacity(0.85), in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(isLocked ? 0.12 : 0.25), lineWidth: 1) }
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    private var hintBubble: some View {
        Text("Finish \(tower.unlockedAfter ?? "the previous tower") to unlock")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(hex: 0x14244A), in: .capsule)
            .overlay { Capsule().strokeBorder(Theme.amberSoft.opacity(0.6), lineWidth: 1) }
            .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }
}

// MARK: - Shake

/// Horizontal shake driven by an animated 0...1 progress value.
private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0)
        )
    }
}

#Preview {
    NavigationStack {
        TowerTrailView()
    }
    .environment(AppState())
}
