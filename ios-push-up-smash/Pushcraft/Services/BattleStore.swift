import Foundation
import Observation
import Supabase

/// Errors from creating, joining or cancelling battles.
enum BattleError: LocalizedError {
    case offline
    case notFound
    case ownBattle
    case closed
    case server

    var errorDescription: String? {
        switch self {
        case .offline: "You're offline. Connect to the internet and try again."
        case .notFound: "Battle not found. Check the code and try again."
        case .ownBattle: "You can't join your own battle."
        case .closed: "This battle is no longer open to join."
        case .server: "Something went wrong. Please try again."
        }
    }

    static func from(_ error: Error) -> BattleError {
        if BackendFailure.isOffline(error) { return .offline }
        switch BackendFailure.code(error) {
        case "battle_not_found": return .notFound
        case "own_battle": return .ownBattle
        case "battle_closed": return .closed
        default: return .server
        }
    }
}

/// The signed-in player's battles. All writes go through database functions
/// that check codes, deadlines and the single run per player.
@Observable
final class BattleStore {
    private(set) var battles: [Battle] = []
    private(set) var hasLoaded = false

    /// The host's single waiting invitation, if any.
    var invitation: Battle? { battles.first { $0.isInvitation } }

    var activeBattles: [Battle] {
        battles.filter { $0.phase == .waiting || $0.phase == .active }
    }

    var completedBattles: [Battle] {
        battles.filter { $0.phase == .completed }
    }

    func battle(withID id: UUID) -> Battle? {
        battles.first { $0.id == id }
    }

    func load() async throws {
        do {
            let dtos: [BattleDTO] = try await Backend.client.rpc("get_my_battles").execute().value
            battles = dtos.map(Battle.init(dto:))
            hasLoaded = true
        } catch {
            print("[Battles] Load failed: \(error.localizedDescription)")
            throw BattleError.from(error)
        }
    }

    /// Creates the host's invitation, or reuses the waiting one with the chosen exercise.
    func createInvitation(exercise: Exercise) async throws -> Battle {
        do {
            let dto: BattleDTO = try await Backend.client
                .rpc("create_battle", params: ExerciseParams(exercise: exercise.serverValue))
                .execute()
                .value
            return upsert(Battle(dto: dto))
        } catch {
            print("[Battles] Create failed: \(error.localizedDescription)")
            throw BattleError.from(error)
        }
    }

    func join(code: String) async throws -> Battle {
        do {
            let dto: BattleDTO = try await Backend.client
                .rpc("join_battle", params: CodeParams(code: code))
                .execute()
                .value
            return upsert(Battle(dto: dto))
        } catch {
            print("[Battles] Join failed: \(error.localizedDescription)")
            throw BattleError.from(error)
        }
    }

    func cancel(id: UUID) async throws {
        do {
            try await Backend.client.rpc("cancel_battle", params: BattleIDParams(battleID: id)).execute()
            battles.removeAll { $0.id == id }
        } catch {
            print("[Battles] Cancel failed: \(error.localizedDescription)")
            throw BattleError.from(error)
        }
    }

    func reset() {
        battles = []
        hasLoaded = false
    }

    @discardableResult
    private func upsert(_ battle: Battle) -> Battle {
        if let index = battles.firstIndex(where: { $0.id == battle.id }) {
            battles[index] = battle
        } else {
            battles.insert(battle, at: 0)
        }
        return battle
    }
}
