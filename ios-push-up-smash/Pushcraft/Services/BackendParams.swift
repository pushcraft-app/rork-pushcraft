import Foundation

// Encodable argument shapes for the database functions. Keys must match the
// Postgres parameter names exactly.

nonisolated struct StartSessionParams: Encodable, Sendable {
    let sessionID: UUID
    let exercise: String
    let timezone: String
    let battleID: UUID?
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case exercise = "p_exercise"
        case timezone = "p_timezone"
        case battleID = "p_battle_id"
        case appVersion = "p_app_version"
    }
}

nonisolated struct CompleteSessionParams: Encodable, Sendable {
    let sessionID: UUID
    let reps: Int
    let blocks: Int
    let endReason: String
    let clientEndedAt: Date?

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case reps = "p_reps"
        case blocks = "p_blocks"
        case endReason = "p_end_reason"
        case clientEndedAt = "p_client_ended_at"
    }
}

nonisolated struct ExerciseParams: Encodable, Sendable {
    let exercise: String

    enum CodingKeys: String, CodingKey {
        case exercise = "p_exercise"
    }
}

nonisolated struct CodeParams: Encodable, Sendable {
    let code: String

    enum CodingKeys: String, CodingKey {
        case code = "p_code"
    }
}

nonisolated struct BattleIDParams: Encodable, Sendable {
    let battleID: UUID

    enum CodingKeys: String, CodingKey {
        case battleID = "p_battle_id"
    }
}

nonisolated struct NameParams: Encodable, Sendable {
    let name: String

    enum CodingKeys: String, CodingKey {
        case name = "p_name"
    }
}

nonisolated struct ProfileUpdate: Encodable, Sendable {
    let displayName: String
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }

    /// Encodes `avatar_path` as an explicit null so removing a photo clears it.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(avatarPath, forKey: .avatarPath)
    }
}
