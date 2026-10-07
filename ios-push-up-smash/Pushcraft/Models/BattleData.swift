import Foundation

/// Outcome of a finished battle from the signed-in player's side.
enum BattleOutcome: Sendable {
    case victory
    case defeat
    case draw
    /// Deadline passed with no scores submitted.
    case expired

    var title: String {
        switch self {
        case .victory: "Victory"
        case .defeat: "Defeat"
        case .draw: "Draw"
        case .expired: "Expired"
        }
    }
}

/// Lifecycle phase of a battle or invitation.
enum BattlePhase: Sendable {
    /// Host's invitation, no opponent yet.
    case waiting
    /// Opponent joined; both players have until the deadline to submit.
    case active
    /// Result fixed (completed or expired).
    case completed
}

/// Final scores. The opponent's score is only revealed once the result is fixed.
struct BattleResult: Sendable {
    let myScore: Int?
    let opponentScore: Int?
    let outcome: BattleOutcome
    let date: Date
}

/// A battle as seen by the signed-in player, built from `battle_view`.
struct Battle: Identifiable, Sendable {
    let id: UUID
    let code: String
    let isHost: Bool
    let createdDate: Date
    let exercise: Exercise
    let phase: BattlePhase
    let opponentName: String?
    let opponentAvatarPath: String?
    let opponentSubmitted: Bool
    let inviteExpiresAt: Date
    let deadlineAt: Date?
    let myRunStarted: Bool
    let mySubmitted: Bool
    let myScore: Int?
    let mySessionID: UUID?
    let result: BattleResult?

    var isInvitation: Bool { isHost && phase == .waiting }

    /// True while this player can still start their single run.
    var canStartRun: Bool {
        phase == .active && !mySubmitted && (deadlineAt.map { $0 > Date() } ?? false)
    }

    var statusText: String {
        switch phase {
        case .waiting:
            return "Waiting for opponent"
        case .active:
            if mySubmitted {
                return opponentSubmitted ? "Finalizing result" : "Waiting for \(opponentName ?? "opponent")"
            }
            return myRunStarted ? "Run in progress" : "Your turn"
        case .completed:
            return result?.outcome.title ?? "Finished"
        }
    }

    init(dto: BattleDTO) {
        id = dto.id
        code = dto.code
        isHost = dto.isHost
        createdDate = dto.createdAt
        exercise = Exercise(serverValue: dto.exercise) ?? .pushUps
        switch dto.status {
        case "waiting": phase = .waiting
        case "active": phase = .active
        default: phase = .completed
        }
        opponentName = dto.opponent?.displayName
        opponentAvatarPath = dto.opponent?.avatarPath
        opponentSubmitted = dto.opponent?.submitted ?? false
        inviteExpiresAt = dto.inviteExpiresAt
        deadlineAt = dto.deadlineAt
        myRunStarted = dto.myRunStarted
        mySubmitted = dto.mySubmitted
        myScore = dto.myScore
        mySessionID = dto.mySessionId

        if phase == .completed {
            let outcome: BattleOutcome = switch dto.outcome {
            case "victory": .victory
            case "defeat": .defeat
            case "draw": .draw
            default: .expired
            }
            result = BattleResult(
                myScore: dto.myScore,
                opponentScore: dto.opponent?.score,
                outcome: outcome,
                date: dto.completedAt ?? dto.createdAt
            )
        } else {
            result = nil
        }
    }
}

/// Navigation destinations inside the Battles stack.
enum BattleRoute: Hashable {
    case details(UUID)
    case result(UUID)
}
