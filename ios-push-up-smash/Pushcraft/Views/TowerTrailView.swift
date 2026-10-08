import SwiftUI

/// The Tower Trail: the painted journey map fills the phone edge-to-edge and
/// scrolls with push/pull bounce. Live tower cards sit exactly over the towers
/// painted into the artwork — tapping an unlocked tower opens its journey.
struct TowerTrailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Native pixel size of the painted map artwork.
    private static let mapSize = CGSize(width: 852, height: 1847)

    /// Card centers as fractions of the painted map, first tower at the bottom.
    private static let cardSlots: [(x: CGFloat, y: CGFloat)] = [
        (0.278, 0.745), // Oakspire
        (0.711, 0.609), // Stonewatch
        (0.276, 0.475), // Frostkeep
        (0.712, 0.339), // Emberhold
        (0.276, 0.193)  // Skyward Spire
    ]

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

    var body: some View {
        GeometryReader { geo in
            // Scale the painting so it covers the entire screen; any leftover
            // height becomes scrollable push/pull space.
            let coverScale = max(geo.size.width / Self.mapSize.width, geo.size.height / Self.mapSize.height)
            let mapWidth = Self.mapSize.width * coverScale
            let mapHeight = Self.mapSize.height * coverScale
            let contentHeight = max(mapHeight, geo.size.height)
            let mapTop = (contentHeight - mapHeight) / 2
            let mapLeading = (geo.size.width - mapWidth) / 2

            ZStack(alignment: .topLeading) {
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        Theme.night
                            .frame(width: geo.size.width, height: contentHeight)

                        mapImage(width: mapWidth, height: mapHeight)
                            .offset(x: mapLeading, y: mapTop)

                        ForEach(Array(towers.enumerated()), id: \.element.id) { index, tower in
                            let slot = Self.cardSlots[min(index, Self.cardSlots.count - 1)]
                            TrailNode(
                                tower: tower,
                                isCurrent: tower.id == currentTowerID,
                                size: geo.size.width * 0.25,
                                glowPulse: glowPulse,
                                isShaking: hintTowerID == tower.id,
                                shakeProgress: shakeProgress,
                                showsHint: hintTowerID == tower.id,
                                onTap: { handleTap(tower) }
                            )
                            .position(
                                x: mapLeading + mapWidth * slot.x,
                                y: mapTop + mapHeight * slot.y
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: contentHeight)
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

    /// The painted map at its exact aspect ratio so nothing is stretched.
    private func mapImage(width: CGFloat, height: CGFloat) -> some View {
        Image("trail_painted_map")
            .resizable()
            .frame(width: width, height: height)
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

/// One tower on the trail: a rounded card seated exactly over its painted
/// counterpart, with a silver border and lock badge when locked, a gold
/// glowing border when unlocked, and its name label hanging below.
private struct TrailNode: View {
    let tower: Tower
    let isCurrent: Bool
    let size: CGFloat
    let glowPulse: Bool
    let isShaking: Bool
    let shakeProgress: CGFloat
    let showsHint: Bool
    let onTap: () -> Void

    private var isLocked: Bool { tower.status == .locked }
    private var isCompleted: Bool { tower.status == .completed }

    /// Thumbnail cropped from the painted map so the card matches the
    /// artwork pixel-for-pixel.
    private var thumbnailName: String {
        "card_\(TowerArt.key(for: tower.id) ?? "oakspire")"
    }

    var body: some View {
        Button(action: onTap) {
            card
                .overlay(alignment: .bottom) {
                    label
                        .offset(y: size * 0.24)
                }
        }
        .buttonStyle(PressScaleStyle())
        .modifier(ShakeEffect(amount: size * 0.06, animatableData: isShaking ? shakeProgress : 0))
        .overlay(alignment: .top) {
            if showsHint {
                hintBubble
                    .offset(y: -(size * 0.62))
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

    private var card: some View {
        ZStack {
            if isCurrent {
                glow
            }

            Image(thumbnailName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.24, style: .continuous))
                .overlay { border }
                .shadow(color: .black.opacity(0.45), radius: 7, y: 3)

            if isLocked {
                statusBadge(symbol: "lock.fill", fill: Color(hex: 0x23262E).opacity(0.94), symbolColor: .white)
            } else if isCompleted {
                statusBadge(symbol: "checkmark", fill: Theme.amberSoft, symbolColor: Color(hex: 0x3A2200))
            }
        }
    }

    /// Brushed silver for locked towers, warm gold for unlocked ones —
    /// matching the sample artwork's card treatments.
    private var border: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .strokeBorder(
                .linearGradient(
                    colors: isLocked
                        ? [Color(hex: 0xF2F5FA), Color(hex: 0x8E99A8)]
                        : [Color(hex: 0xFFE9A8), Color(hex: 0xD99A2B)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: max(4, size * 0.05)
            )
            .shadow(color: isLocked ? .black.opacity(0.3) : Theme.amberSoft.opacity(0.75), radius: isLocked ? 3 : 9)
    }

    /// Pulsing golden halo behind the current tower's card.
    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.amberSoft.opacity(0.55), Theme.amberSoft.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.72
                )
            )
            .frame(width: size * 1.45, height: size * 1.45)
            .scaleEffect(glowPulse ? 1.08 : 0.92)
            .opacity(glowPulse ? 1 : 0.65)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)
    }

    private func statusBadge(symbol: String, fill: Color, symbolColor: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.15, weight: .heavy))
            .foregroundStyle(symbolColor)
            .frame(width: size * 0.34, height: size * 0.34)
            .background(fill, in: .circle)
            .overlay { Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5) }
            .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            .offset(x: size * 0.34, y: size * 0.34)
    }

    /// Bold white serif name plate hanging below the card, like the sample.
    private var label: some View {
        Text(tower.name)
            .font(.system(size: max(15, size * 0.19), weight: .heavy, design: .serif))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.95), radius: 3, y: 1)
            .shadow(color: .black.opacity(0.5), radius: 7, y: 2)
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
