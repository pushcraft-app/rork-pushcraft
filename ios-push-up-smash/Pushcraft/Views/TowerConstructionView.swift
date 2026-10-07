import SwiftUI

/// Maps towers (by id or display name) to their parts-library key.
enum TowerArt {
    private static let keys: Set<String> = ["oakspire", "stonewatch", "frostkeep", "emberhold", "skyward_spire"]

    /// Resolves a tower id or display name ("Skyward Spire") to its key.
    static func key(for raw: String?) -> String? {
        guard let raw else { return nil }
        var normalized = ""
        var lastWasSeparator = true
        for char in raw.lowercased() {
            if char.isLetter || char.isNumber {
                normalized.append(char)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                normalized.append("_")
                lastWasSeparator = true
            }
        }
        while normalized.hasSuffix("_") { normalized.removeLast() }
        return keys.contains(normalized) ? normalized : nil
    }
}

/// A tower assembled from its nine cut-out stage parts.
/// - Built stages render in full color.
/// - The stage being built shows its dashed outline and fades in with every rep.
/// - Later stages are invisible.
/// - A brand-new or locked tower shows the whole tower as a dashed silhouette.
struct TowerConstructionView: View {
    let towerID: String?
    var builtStages: Int
    /// Completion of the stage being built, 0...1.
    var stageFraction: Double
    var isLocked: Bool

    private let key: String?

    init(towerID: String?, builtStages: Int, stageFraction: Double = 0, isLocked: Bool = false) {
        self.towerID = towerID
        self.builtStages = builtStages
        self.stageFraction = stageFraction
        self.isLocked = isLocked
        self.key = TowerArt.key(for: towerID)
    }

    private var built: Int { min(max(builtStages, 0), TowerParts.stageCount) }
    private var fraction: Double { min(max(stageFraction, 0), 1) }
    private var isUnstarted: Bool { isLocked || (built == 0 && fraction <= 0.001) }
    private var currentStage: Int? { built < TowerParts.stageCount ? built + 1 : nil }

    var body: some View {
        ZStack {
            if let key, TowerParts.entry(for: key) != nil {
                if isUnstarted {
                    TowerOutlineLayer(key: key, kind: .silhouette, intensity: isLocked ? 0.45 : 1)
                        .transition(.opacity)
                } else {
                    ForEach(0..<built, id: \.self) { index in
                        TowerPartLayer(key: key, stage: index + 1)
                    }
                    if let currentStage {
                        TowerPartLayer(key: key, stage: currentStage)
                            .opacity(fraction)
                        TowerOutlineLayer(key: key, kind: .part(currentStage), intensity: 1 - 0.45 * fraction)
                    }
                }
            } else {
                Image("watchtower_construction")
                    .resizable()
                    .scaledToFit()
                    .opacity(isUnstarted ? 0.25 : 1)
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .animation(.easeInOut(duration: 0.6), value: fraction)
        .animation(.easeInOut(duration: 0.5), value: built)
        .animation(.easeInOut(duration: 0.4), value: isUnstarted)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isLocked { return "Locked tower" }
        if built >= TowerParts.stageCount { return "Tower complete" }
        return "\(built) of \(TowerParts.stageCount) stages built"
    }
}

#Preview("States") {
    HStack(spacing: 12) {
        TowerConstructionView(towerID: "oakspire", builtStages: 0)
        TowerConstructionView(towerID: "stonewatch", builtStages: 0, stageFraction: 0.5)
        TowerConstructionView(towerID: "frostkeep", builtStages: 4, stageFraction: 0.3)
        TowerConstructionView(towerID: "emberhold", builtStages: 9)
        TowerConstructionView(towerID: "skyward_spire", builtStages: 0, isLocked: true)
    }
    .frame(height: 220)
    .padding(12)
    .background(Theme.towersNavy)
}
