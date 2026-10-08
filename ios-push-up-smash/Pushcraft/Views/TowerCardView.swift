import SwiftUI

/// A single tower card in the horizontal carousel: status badge, tower
/// artwork, name, level info and progress. The gold styling of the current
/// tower is tied to its status, independent of which card is centered.
/// Tapping a locked card fires `onLockedTap`; any unlocked card opens its
/// journey via `onOpen`.
struct TowerCardView: View {
    let tower: Tower
    let isCentered: Bool
    let onLockedTap: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StatusBadgeView(status: tower.status)
                .padding(.top, 14)

            artwork
                .padding(.top, 14)

            Text(tower.name)
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 12)

            Text(stageLine)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.mist)
                .padding(.top, 3)

            progressBar
                .padding(.top, 12)

            Text("\(tower.percentComplete)% complete")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(hex: tower.status == .inProgress ? 0x131F38 : 0x111B2F),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            if tower.status == .inProgress {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        .linearGradient(
                            colors: [Theme.amberSoft.opacity(0.9), Theme.amberDeep.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .shadow(color: tower.status == .inProgress ? Theme.amber.opacity(0.28) : .clear, radius: 18)
        .contentShape(.rect(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            HapticService.ui.tap()
            guard tower.status == .locked else {
                onOpen()
                return
            }
            onLockedTap()
        }
    }

    private var stageLine: String {
        switch tower.status {
        case .completed: "All \(tower.totalStages) stages built"
        case .inProgress: "Stage \(tower.currentStage) of \(tower.totalStages)"
        case .locked: "\(tower.totalStages) stages · \(String(tower.totalReps)) reps"
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack {
            TowerConstructionView(
                towerID: tower.id,
                builtStages: tower.builtStages,
                stageFraction: tower.stageFraction,
                isLocked: tower.status == .locked
            )
            if tower.status == .locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 6)
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.14))
                if tower.progress > 0 {
                    Capsule()
                        .fill(fillGradient)
                        .frame(width: max(proxy.size.width * tower.progress, 12))
                        .shadow(color: fillGlow, radius: 5)
                }
            }
        }
        .frame(height: 10)
    }

    private var fillGradient: some ShapeStyle {
        switch tower.status {
        case .completed:
            LinearGradient(
                colors: [Color(hex: 0x4ADE80), Color(hex: 0x22B45E)],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            LinearGradient(
                colors: [Theme.amberSoft, Theme.amberDeep],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var fillGlow: Color {
        tower.status == .completed
            ? Color(hex: 0x3DDC84).opacity(0.7)
            : Theme.amberDeep.opacity(0.7)
    }
}

#Preview {
    TowerCardView(tower: Tower.samples[1], isCentered: true, onLockedTap: {}, onOpen: {})
        .frame(width: 250, height: 430)
        .background(Color(hex: 0x0B1426))
}
