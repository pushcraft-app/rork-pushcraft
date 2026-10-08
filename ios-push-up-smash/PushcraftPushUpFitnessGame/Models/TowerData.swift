import Foundation

/// Build state of a tower for the signed-in user.
enum TowerStatus: Sendable {
    case completed
    case inProgress
    case locked
}

/// One tower in the progression path, combining the shared definition with
/// the user's construction progress.
struct Tower: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let status: TowerStatus
    let currentStage: Int
    let totalStages: Int
    let totalReps: Int
    /// Overall construction progress across all stages, 0...1.
    let progress: Double
    /// Completion of the stage currently being built, 0...1 (0 unless in progress).
    var stageFraction: Double = 0
    /// Tower that must be completed first to unlock this one.
    let unlockedAfter: String?

    var percentComplete: Int { Int((progress * 100).rounded()) }

    /// Number of fully built stages.
    var builtStages: Int {
        switch status {
        case .completed: totalStages
        case .inProgress: max(currentStage - 1, 0)
        case .locked: 0
        }
    }
}

extension Tower {
    /// Preview samples only.
    static let samples: [Tower] = [
        Tower(id: "oakspire", name: "Oakspire", status: .completed, currentStage: 9, totalStages: 9, totalReps: 450, progress: 1, unlockedAfter: nil),
        Tower(id: "stonewatch", name: "Stonewatch", status: .inProgress, currentStage: 2, totalStages: 9, totalReps: 630, progress: 0.12, stageFraction: 0.4, unlockedAfter: "Oakspire"),
        Tower(id: "frostkeep", name: "Frostkeep", status: .locked, currentStage: 0, totalStages: 9, totalReps: 990, progress: 0, unlockedAfter: "Stonewatch")
    ]
}
