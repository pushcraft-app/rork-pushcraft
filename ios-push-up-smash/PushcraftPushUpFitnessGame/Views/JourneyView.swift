import SwiftUI

/// Journey screen: every construction stage of the current tower as a
/// timeline, with the current stage's rep progress.
struct JourneyView: View {
    let data: HomeData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A1730), Theme.night],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    backButton

                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR JOURNEY")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(Theme.mist)
                        Text(data.towerName)
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.ivory)
                        Text("Stage \(data.stageNumber) of \(data.totalStages) · building \(data.stageName)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(data.journey) { stage in
                            stageRow(stage)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Stage rows

    @ViewBuilder
    private func stageRow(_ stage: JourneyStage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                stageBadge(stage)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stage \(stage.number) · \(stage.name)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(stage.state == .locked ? Theme.mist.opacity(0.55) : Theme.ivory)
                    Text(stageCaption(stage))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(stage.state == .locked ? 0.6 : 1))
                }

                Spacer()

                Text(stageStatusLabel(stage))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(statusColor(stage))
            }

            if stage.state == .current {
                stageProgressBar(stage)
                    .padding(.leading, 58)
            }
        }
    }

    @ViewBuilder
    private func stageBadge(_ stage: JourneyStage) -> some View {
        ZStack {
            switch stage.state {
            case .completed:
                Circle()
                    .fill(Theme.progressCyan.opacity(0.9))
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x062330))
            case .current:
                Circle()
                    .fill(Theme.cardFill)
                    .overlay(Circle().strokeBorder(Theme.progressCyan, lineWidth: 2))
                Text("\(stage.number)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.progressCyan)
            case .locked:
                Circle()
                    .fill(Theme.cardFill)
                    .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mist.opacity(0.6))
            }
        }
        .frame(width: 44, height: 44)
    }

    private func stageCaption(_ stage: JourneyStage) -> String {
        switch stage.state {
        case .completed: "Construction complete"
        case .current: "\(stage.repsDone) of \(stage.repsRequired) reps"
        case .locked: "\(stage.repsRequired) reps · unlocks after the previous stage"
        }
    }

    private func stageStatusLabel(_ stage: JourneyStage) -> String {
        switch stage.state {
        case .completed: "COMPLETED"
        case .current: "IN PROGRESS"
        case .locked: "LOCKED"
        }
    }

    private func statusColor(_ stage: JourneyStage) -> Color {
        switch stage.state {
        case .completed: Theme.progressCyan
        case .current: Theme.amber
        case .locked: Theme.mist.opacity(0.55)
        }
    }

    // MARK: - Stage progress

    private func stageProgressBar(_ stage: JourneyStage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule()
                        .fill(.linearGradient(colors: [Theme.progressCyan, Color(hex: 0x7BE9FF)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(proxy.size.width * stage.progress, 10))
                        .shadow(color: Theme.progressCyan.opacity(0.7), radius: 5)
                }
            }
            .frame(height: 10)

            Text("\(max(stage.repsRequired - stage.repsDone, 0)) reps to finish \(stage.name)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.mist)
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                Text("Back")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Theme.ivory)
        }
        .buttonStyle(JourneyPressStyle())
    }
}

private struct JourneyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticService.ui.tap() }
            }
    }
}

#Preview {
    JourneyView(data: .mock)
}
