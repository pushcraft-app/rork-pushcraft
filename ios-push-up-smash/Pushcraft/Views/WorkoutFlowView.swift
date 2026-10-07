import StoreKit
import SwiftUI

/// Full-screen container for one registered workout: the camera arena, then
/// the results screen showing the outcome the server accepted, then the stage
/// reveal celebration when the workout finished a construction stage.
struct WorkoutFlowView: View {
    let session: ActiveSession

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var finished: FinishedRun?
    @State private var reveal: StageRevealInfo?
    @State private var showReveal = false

    private struct FinishedRun {
        let reps: Int
        let blocks: Int
        var state: SubmitState
    }

    private struct StageRevealInfo {
        let towerID: String
        let towerName: String
        let stageNumber: Int
        let stageName: String
        let nextStageName: String?
        let firstNewStage: Int
    }

    var body: some View {
        ZStack {
            if showReveal, let reveal {
                StageRevealView(
                    towerID: reveal.towerID,
                    towerName: reveal.towerName,
                    stageNumber: reveal.stageNumber,
                    stageName: reveal.stageName,
                    nextStageName: reveal.nextStageName,
                    firstNewStage: reveal.firstNewStage,
                    onContinue: { dismiss() }
                )
                .transition(.opacity)
            } else if let finished {
                WorkoutResultView(
                    session: session,
                    reps: finished.reps,
                    state: finished.state,
                    onRetry: retry,
                    onDone: handleDone
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ArenaView(session: session, workouts: appState.workouts) { reps, blocks, reason in
                    handleEnd(reps: reps, blocks: blocks, reason: reason)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: finished == nil)
        .animation(.easeInOut(duration: 0.3), value: showReveal)
        .interactiveDismissDisabled()
    }

    private func handleEnd(reps: Int, blocks: Int, reason: WorkoutEndReason) {
        // A regular workout left with no reps has nothing to save.
        if reps == 0 && !session.isBattle {
            appState.workouts.abandon(id: session.id)
            dismiss()
            return
        }
        finished = FinishedRun(reps: reps, blocks: blocks, state: .saving)
        Task {
            let state = await appState.workouts.finish(id: session.id, reps: reps, blocks: blocks, reason: reason)
            finished?.state = state
            prepareRevealIfStageCompleted(state: state)
            requestReviewIfFirstCompleted(state: state)
        }
    }

    /// One-time App Store review prompt after the user's first fully
    /// completed session (30 reps). The system throttles actual display.
    private func requestReviewIfFirstCompleted(state: SubmitState) {
        guard case .saved(let outcome) = state,
              outcome.isCompleted,
              !AppPreferences.shared.hasAskedStoreReview
        else { return }
        AppPreferences.shared.hasAskedStoreReview = true
        requestReview()
    }

    private func handleDone() {
        guard reveal != nil else {
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            showReveal = true
        }
    }

    private func retry() {
        finished?.state = .saving
        Task {
            let state = await appState.workouts.retry(id: session.id)
            finished?.state = state
        }
    }

    /// When the server accepted a workout that finished a stage, remember the
    /// reveal details so the result screen's Done button leads into it.
    private func prepareRevealIfStageCompleted(state: SubmitState) {
        guard case .saved(let outcome) = state,
              let first = outcome.credits.first(where: { $0.stageCompleted })
        else { return }

        // Every stage this workout finished on that tower drops in, in order.
        let completedHere = outcome.credits
            .filter { $0.towerId == first.towerId && $0.stageCompleted }
            .sorted { $0.stageNumber < $1.stageNumber }
        let last = completedHere.last ?? first
        let isTowerDone = last.stageNumber >= TowerParts.stageCount
        let nextName: String? = isTowerDone
            ? nil
            : outcome.credits.first { $0.towerId == first.towerId && $0.stageNumber == last.stageNumber + 1 }?.stageName
                ?? HomeData.stageNames[safe: last.stageNumber]

        reveal = StageRevealInfo(
            towerID: first.towerId,
            towerName: first.towerName,
            stageNumber: last.stageNumber,
            stageName: last.stageName,
            nextStageName: nextName,
            firstNewStage: completedHere.first?.stageNumber ?? last.stageNumber
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
