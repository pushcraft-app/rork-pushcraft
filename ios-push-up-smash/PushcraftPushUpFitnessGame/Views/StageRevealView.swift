import SwiftUI

/// Full-screen celebration after a workout that completes one or more
/// construction stages: each finished part drops into place with a bounce,
/// a puff of stone dust and a stone thump (sound + haptics), a golden shimmer
/// sweeps over it, sparkles keep twinkling, and the next stage's dashed outline
/// fades in. Finishing a whole tower adds a bigger boom and finale.
struct StageRevealView: View {
    let towerID: String?
    let towerName: String
    /// The last stage completed by this workout (announced in the title).
    let stageNumber: Int
    let stageName: String
    /// Name of the next stage, or nil when the whole tower is now complete.
    let nextStageName: String?
    /// First stage completed by this workout; stages before it were already built.
    let firstNewStage: Int
    var onContinue: () -> Void

    @State private var announced = false
    @State private var droppedStages: Set<Int> = []
    @State private var landedStages: Set<Int> = []
    @State private var shimmerPhase: CGFloat = -1
    @State private var showNextOutline = false
    @State private var burstDate: Date?
    @State private var sparkles: [Sparkle] = []
    @State private var sound = SoundService()

    private let key: String?
    private let towerHeight: CGFloat = 380

    init(
        towerID: String?,
        towerName: String,
        stageNumber: Int,
        stageName: String,
        nextStageName: String?,
        firstNewStage: Int,
        onContinue: @escaping () -> Void
    ) {
        self.towerID = towerID
        self.towerName = towerName
        self.stageNumber = min(max(stageNumber, 1), TowerParts.stageCount)
        self.stageName = stageName
        self.nextStageName = nextStageName
        self.firstNewStage = min(max(firstNewStage, 1), min(max(stageNumber, 1), TowerParts.stageCount))
        self.onContinue = onContinue
        self.key = TowerArt.key(for: towerID)
    }

    private var newStages: [Int] { Array(firstNewStage...stageNumber) }
    private var nextStage: Int? { stageNumber < TowerParts.stageCount ? stageNumber + 1 : nil }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                titleBlock
                    .padding(.top, 44)
                    .opacity(announced ? 1 : 0)
                    .offset(y: announced ? 0 : 18)

                towerHero
                    .padding(.top, 14)

                nextLine
                    .padding(.top, 18)
                    .opacity(showNextOutline ? 1 : 0)

                Spacer(minLength: 16)

                GoldButton(title: "Continue") {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                } action: { onContinue() }
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
        .preferredColorScheme(.dark)
        .task { await play() }
    }

    // MARK: - Layers

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A1730), Theme.night], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(
                colors: [Theme.gold.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("STAGE \(stageNumber) COMPLETE")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.amberSoft)
            Text(stageName)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            Text(towerName)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var towerHero: some View {
        if let key, TowerParts.entry(for: key) != nil {
            ZStack {
                ForEach(Array(1..<firstNewStage), id: \.self) { stage in
                    TowerPartLayer(key: key, stage: stage)
                }

                if let nextStage {
                    TowerOutlineLayer(key: key, kind: .part(nextStage))
                        .opacity(showNextOutline ? 1 : 0)
                }

                ForEach(newStages, id: \.self) { stage in
                    droppingPart(key: key, stage: stage)
                }

                ForEach(newStages, id: \.self) { stage in
                    DustBurst(isActive: landedStages.contains(stage))
                        .modifier(PartAnchor(key: key, stage: stage))
                }

                sparkleField
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .frame(height: towerHeight)
            .frame(maxWidth: .infinity)
        } else {
            Image("watchtower_construction")
                .resizable()
                .scaledToFit()
                .frame(height: towerHeight)
                .overlay { sparkleField }
        }
    }

    private func droppingPart(key: String, stage: Int) -> some View {
        let isDropped = droppedStages.contains(stage)
        return TowerPartLayer(key: key, stage: stage)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Theme.gold.opacity(0.75), .white.opacity(0.9), Theme.gold.opacity(0.75), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.45)
                    .rotationEffect(.degrees(18))
                    .offset(x: shimmerPhase * geo.size.width)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                    .blendMode(.plusLighter)
                }
                .mask { TowerPartLayer(key: key, stage: stage) }
                .allowsHitTesting(false)
            }
            .offset(y: isDropped ? 0 : -towerHeight * 0.55)
            .opacity(isDropped ? 1 : 0)
    }

    private var nextLine: some View {
        Group {
            if let next = nextStageName {
                Text("Next up: \(next)")
                    .foregroundStyle(Theme.mist)
            } else {
                Label("\(towerName) is complete!", image: "stat_tower")
                    .foregroundStyle(Theme.gold)
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
    }

    // MARK: - Sparkles

    private struct Sparkle: Identifiable {
        let id: Int
        let angle: Double
        let distance: Double
        let size: CGFloat
        let isGold: Bool
        let twinkleSpeed: Double
        let phase: Double
        let spin: Double
        let drift: Double
    }

    /// Sparkles burst out from the landing point, then keep twinkling:
    /// each pulses, rotates and drifts on its own timing.
    private var sparkleField: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: burstDate == nil)) { timeline in
                let elapsed = burstDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                let burst = min(max(elapsed / 0.7, 0), 1)
                let eased = 1 - pow(1 - burst, 3)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.58)

                ZStack {
                    ForEach(sparkles) { sparkle in
                        let t = elapsed * sparkle.twinkleSpeed + sparkle.phase
                        let twinkle = 0.55 + 0.45 * sin(t)
                        let dx = cos(sparkle.angle) * sparkle.distance * eased + sin(elapsed * 0.6 + sparkle.phase) * sparkle.drift
                        let dy = sin(sparkle.angle) * sparkle.distance * eased + cos(elapsed * 0.5 + sparkle.phase) * sparkle.drift
                        Image(systemName: "sparkle")
                            .font(.system(size: sparkle.size, weight: .bold))
                            .foregroundStyle(sparkle.isGold ? Theme.gold : Color.white)
                            .shadow(color: (sparkle.isGold ? Theme.gold : Theme.progressCyan).opacity(0.85), radius: 5)
                            .scaleEffect(burstDate == nil ? 0.1 : (0.35 + 0.65 * eased) * (0.6 + 0.5 * twinkle))
                            .rotationEffect(.degrees(elapsed * sparkle.spin))
                            .opacity(burstDate == nil ? 0 : eased * (0.35 + 0.65 * twinkle))
                            .position(x: center.x + dx, y: center.y + dy)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func makeSparkles() -> [Sparkle] {
        (0..<20).map { index in
            Sparkle(
                id: index,
                angle: Double.random(in: 0...(2 * .pi)),
                distance: .random(in: 60...175),
                size: .random(in: 9...20),
                isGold: index % 3 != 0,
                twinkleSpeed: .random(in: 2.4...5.2),
                phase: .random(in: 0...(2 * .pi)),
                spin: .random(in: -40...40),
                drift: .random(in: 4...12)
            )
        }
    }

    // MARK: - Sequence

    private func play() async {
        sparkles = makeSparkles()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
            announced = true
        }
        try? await Task.sleep(for: .seconds(0.5))

        for (index, stage) in newStages.enumerated() {
            if index > 0 { try? await Task.sleep(for: .seconds(0.32)) }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.52)) {
                _ = droppedStages.insert(stage)
            }
            Task {
                try? await Task.sleep(for: .seconds(0.2))
                // Stone thump synced with the dust and shake; each successive
                // part lands a touch deeper so the build feels weightier.
                sound.play(.drop, pitch: Float(max(0.82 - 0.04 * Double(index), 0.68)), volume: 1)
                HapticService.ui.stoneLand()
                landedStages.insert(stage)
            }
        }

        try? await Task.sleep(for: .seconds(0.22))
        burstDate = Date()
        HapticService.ui.success()
        sound.play(.coins, pitch: 1, volume: 1)
        if nextStageName == nil {
            // The whole tower just finished: a bigger boom and a long
            // double-impact finale.
            sound.play(.shatter, pitch: 0.85, volume: 1)
            HapticService.ui.finale()
        }

        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeInOut(duration: 1.0)) {
            shimmerPhase = 1.6
        }

        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeInOut(duration: 0.6)) {
            showNextOutline = true
        }
    }
}

/// Places a small effect at the bottom-center of a part's footprint in the canvas.
private struct PartAnchor: ViewModifier {
    let key: String
    let stage: Int

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let r = TowerParts.rect(key: key, stage: stage) ?? CGRect(x: 0.2, y: 0.6, width: 0.6, height: 0.3)
            content
                .frame(width: r.width * geo.size.width, height: 60)
                .position(x: r.midX * geo.size.width, y: min(r.maxY * geo.size.height - 24, geo.size.height - 30))
        }
        .allowsHitTesting(false)
    }
}

/// One-shot puff of warm grey stone dust spreading out from a landing.
private struct DustBurst: View {
    let isActive: Bool

    private struct Puff: Identifiable {
        let id: Int
        let x: CGFloat
        let rise: CGFloat
        let size: CGFloat
        let delay: Double
        let tone: Color
    }

    @State private var puffs: [Puff] = (0..<16).map { index in
        let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return Puff(
            id: index,
            x: side * .random(in: 0.15...0.65),
            rise: .random(in: 8...34),
            size: .random(in: 10...24),
            delay: .random(in: 0...0.12),
            tone: [Color(hex: 0xB9A58A), Color(hex: 0x9C8C78), Color(hex: 0xD6C7AE)][index % 3]
        )
    }
    @State private var isSpread = false
    @State private var isFaded = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(puffs) { puff in
                    Circle()
                        .fill(puff.tone.opacity(0.75))
                        .frame(width: puff.size, height: puff.size)
                        .blur(radius: 3)
                        .scaleEffect(isSpread ? 1.8 : 0.3)
                        .offset(
                            x: isSpread ? puff.x * geo.size.width * 0.6 : 0,
                            y: isSpread ? -puff.rise : 0
                        )
                        .opacity(isActive ? (isFaded ? 0 : 0.9) : 0)
                        .animation(.easeOut(duration: 0.7).delay(puff.delay), value: isSpread)
                        .animation(.easeIn(duration: 0.6).delay(0.35 + puff.delay), value: isFaded)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            isSpread = true
            isFaded = true
        }
        .allowsHitTesting(false)
    }
}

#Preview("Foundation reveal") {
    StageRevealView(
        towerID: "oakspire",
        towerName: "Oakspire",
        stageNumber: 1,
        stageName: "The Foundation",
        nextStageName: "The Entrance",
        firstNewStage: 1,
        onContinue: {}
    )
}

#Preview("Tower complete") {
    StageRevealView(
        towerID: "stonewatch",
        towerName: "Stonewatch",
        stageNumber: 9,
        stageName: "The Summit",
        nextStageName: nil,
        firstNewStage: 9,
        onContinue: {}
    )
}
