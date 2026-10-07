import Foundation

/// A workout the server has registered and the arena is running.
struct ActiveSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let exercise: Exercise
    let battleID: UUID?
    /// Local clock time the run started (server start, adjusted for retries).
    let startedAt: Date
    let completionReps: Int
    let battleDurationSeconds: Int

    var isBattle: Bool { battleID != nil }
}

/// How a workout ended, sent to the server with the final counts.
enum WorkoutEndReason: String, Sendable {
    case finished
    case interrupted
    case timer
}

/// A workout saved on this phone until the server accepts it. Persisted per
/// account so crashes, restarts and lost connections never lose reps.
nonisolated struct PendingSession: Codable, Sendable, Identifiable {
    enum State: String, Codable, Sendable {
        /// Start was sent but the server's reply hasn't arrived; retries reuse this ID.
        case registering
        /// The arena is (or was) running; checkpoints keep reps current.
        case active
        /// Finished on the phone, waiting to be accepted.
        case ended
    }

    let id: UUID
    let userID: UUID
    let exercise: String
    let battleID: UUID?
    let createdAt: Date
    var state: State
    var startedAt: Date?
    var reps: Int
    var blocks: Int
    var lastRepAt: Date?
    var updatedAt: Date
    var endedAt: Date?
    var endReason: String?
}

/// What the results screen shows for a finished workout.
enum SubmitState: Equatable, Sendable {
    case saving
    case saved(WorkoutOutcomeDTO)
    /// Kept on the phone; it syncs automatically when the connection returns.
    case queued
    /// The server can't accept this workout (for example, too old).
    case dropped(String)
}
