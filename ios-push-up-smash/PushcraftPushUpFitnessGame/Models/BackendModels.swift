import Foundation

// Response shapes of the database functions. Keys arrive in snake_case and
// are converted by `BackendCoding.decoder`.

nonisolated struct DashboardDTO: Decodable, Sendable {
    let profile: ProfileDTO
    let stats: StatsDTO
    let rules: RulesDTO
    let towers: [TowerDefinitionDTO]
    let stages: [StageDefinitionDTO]
    let progress: [TowerProgressDTO]
}

nonisolated struct ProfileDTO: Decodable, Sendable {
    let id: UUID
    let displayName: String
    let avatarPath: String?
    let timezone: String
}

nonisolated struct StatsDTO: Decodable, Sendable {
    let totalReps: Int
    let pushUpReps: Int
    let sitUpReps: Int
    let totalSessions: Int
    let completedWorkouts: Int
    let completedTowers: Int
    let coinsBalance: Int
    let xpTotal: Int
    let currentStreak: Int
    let longestStreak: Int
    let lastStreakDate: String?
    let overflowReps: Int
}

nonisolated struct RulesDTO: Decodable, Sendable {
    let version: Int
    let completionReps: Int
    let xpPerCompleted: Int
    let battleDurationSeconds: Int
}

nonisolated struct TowerDefinitionDTO: Decodable, Sendable {
    let id: String
    let name: String
    let sortOrder: Int
    let artKey: String?
}

nonisolated struct StageDefinitionDTO: Decodable, Sendable {
    let towerId: String
    let stageNumber: Int
    let name: String
    let repsRequired: Int
}

nonisolated struct TowerProgressDTO: Decodable, Sendable {
    let towerId: String
    let status: String
    let currentStage: Int
    let repsIntoStage: Int
    let stageTarget: Int
}

nonisolated struct StartSessionDTO: Decodable, Sendable {
    let sessionId: UUID
    let startedAt: Date
    let exercise: String
    let source: String
    let battleId: UUID?
    let rulesVersion: Int
    let status: String
}

/// The accepted, stored outcome of one workout. Retries return this same value.
nonisolated struct WorkoutOutcomeDTO: Decodable, Sendable, Hashable {
    let sessionId: UUID
    let exercise: String
    let source: String
    let battleId: UUID?
    let endReason: String
    let reps: Int
    let repsReported: Int
    let blocksSmashed: Int
    let coinsAwarded: Int
    let xpAwarded: Int
    let isCompleted: Bool
    let completionReps: Int
    let streakDayAwarded: Bool
    let localDate: String
    let credits: [StageCreditDTO]
    let towersCompleted: [TowerReferenceDTO]
    let overflowReps: Int
    let battleSubmission: String?
    let rulesVersion: Int
}

nonisolated struct StageCreditDTO: Decodable, Sendable, Hashable {
    let towerId: String
    let towerName: String
    let stageNumber: Int
    let stageName: String
    let reps: Int
    let stageTarget: Int
    let stageCompleted: Bool
}

nonisolated struct TowerReferenceDTO: Decodable, Sendable, Hashable {
    let towerId: String
    let towerName: String
}

nonisolated struct BattleDTO: Decodable, Sendable {
    let id: UUID
    let code: String
    let exercise: String
    let status: String
    let isHost: Bool
    let createdAt: Date
    let inviteExpiresAt: Date
    let joinedAt: Date?
    let deadlineAt: Date?
    let completedAt: Date?
    let durationSeconds: Int
    let outcome: String?
    let myRunStarted: Bool
    let mySubmitted: Bool
    let myScore: Int?
    let mySessionId: UUID?
    let opponent: BattleOpponentDTO?
}

nonisolated struct BattleOpponentDTO: Decodable, Sendable {
    let userId: UUID?
    let displayName: String
    let avatarPath: String?
    let submitted: Bool
    let score: Int?
}
