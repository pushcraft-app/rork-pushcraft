import Foundation
import Observation
import Supabase

/// Errors shown when a workout can't start.
enum WorkoutError: LocalizedError {
    case offline
    case signedOut
    case battleClosed
    case battleRunUsed
    case server

    var errorDescription: String? {
        switch self {
        case .offline: "Connect to the internet to start. Workouts need a connection to begin."
        case .signedOut: "Sign in again to start a workout."
        case .battleClosed: "This battle is no longer open."
        case .battleRunUsed: "You've already used your run for this battle."
        case .server: "Couldn't start the workout. Please try again."
        }
    }

    static func from(_ error: Error) -> WorkoutError {
        if BackendFailure.isOffline(error) { return .offline }
        switch BackendFailure.code(error) {
        case "battle_closed", "battle_not_found": return .battleClosed
        case "battle_run_used": return .battleRunUsed
        case "not_authenticated": return .signedOut
        default: return .server
        }
    }
}

/// Owns the workout lifecycle on the phone: online start, rep checkpoints,
/// and duplicate-safe submission. Unsent workouts are stored per account on
/// disk, so crashes and lost connections never lose reps, and every retry
/// reuses the same session ID.
@Observable
final class WorkoutService {
    private(set) var pending: [PendingSession] = []
    private(set) var isSyncing = false

    @ObservationIgnored private var userID: UUID?
    @ObservationIgnored private(set) var activeSessionID: UUID?
    /// Called after the server accepts a workout so screens can refresh.
    @ObservationIgnored var onAccepted: ((WorkoutOutcomeDTO) -> Void)?

    /// Workouts waiting to sync, excluding the one currently in the arena.
    var unsyncedCount: Int {
        pending.filter { $0.id != activeSessionID && $0.state != .registering }.count
    }

    // MARK: - Account scoping

    func activate(userID: UUID) {
        self.userID = userID
        pending = Self.load(userID: userID)
    }

    func deactivate() {
        userID = nil
        activeSessionID = nil
        pending = []
    }

    /// Removes this account's unsent workouts (used after account deletion).
    func discardAll(for userID: UUID) {
        try? FileManager.default.removeItem(at: Self.fileURL(userID: userID))
        if self.userID == userID {
            pending = []
        }
    }

    func pendingRun(forBattle battleID: UUID) -> PendingSession? {
        pending.first { $0.battleID == battleID }
    }

    // MARK: - Start (online only)

    /// Registers the workout with the server before the arena opens. Fails
    /// with `.offline` when there's no connection. A battle run whose start
    /// reply was lost reuses its saved session ID, so the single run per
    /// battle is never burned by a network hiccup.
    func start(exercise: Exercise, battleID: UUID?, rules: RulesDTO?) async throws -> ActiveSession {
        let session = try prepare(exercise: exercise, battleID: battleID, rules: rules)
        return try await register(session)
    }

    /// Builds a battle run without telling the server yet, so the player can
    /// wait for their friend and leave without using up their single run.
    /// Reuses the session ID of a run whose start reply was lost.
    func prepare(exercise: Exercise, battleID: UUID?, rules: RulesDTO?) throws -> ActiveSession {
        guard userID != nil else { throw WorkoutError.signedOut }
        let existing = battleID.flatMap { id in pending.first { $0.battleID == id && $0.state == .registering } }
        return ActiveSession(
            id: existing?.id ?? UUID(),
            exercise: exercise,
            battleID: battleID,
            startedAt: Date(),
            completionReps: rules?.completionReps ?? 30,
            battleDurationSeconds: rules?.battleDurationSeconds ?? 60
        )
    }

    /// Registers a prepared run with the server. For battles this happens at GO.
    func register(_ session: ActiveSession) async throws -> ActiveSession {
        guard let userID else { throw WorkoutError.signedOut }
        let exercise = session.exercise
        let battleID = session.battleID

        var record: PendingSession
        if let existing = pending.first(where: { $0.id == session.id && $0.state == .registering }) {
            record = existing
        } else {
            record = PendingSession(
                id: session.id,
                userID: userID,
                exercise: exercise.serverValue,
                battleID: battleID,
                createdAt: Date(),
                state: .registering,
                startedAt: nil,
                reps: 0,
                blocks: 0,
                lastRepAt: nil,
                updatedAt: Date(),
                endedAt: nil,
                endReason: nil
            )
            upsert(record)
        }

        do {
            let response: StartSessionDTO = try await Backend.client
                .rpc(
                    "start_workout_session",
                    params: StartSessionParams(
                        sessionID: record.id,
                        exercise: exercise.serverValue,
                        timezone: TimeZone.current.identifier,
                        battleID: battleID,
                        appVersion: Backend.appVersion
                    )
                )
                .execute()
                .value

            let startedAt = Date()
            record.state = .active
            record.startedAt = startedAt
            record.updatedAt = startedAt
            upsert(record)
            activeSessionID = record.id
            print("[Workout] Started session \(record.id) (\(response.source))")

            return ActiveSession(
                id: record.id,
                exercise: Exercise(serverValue: response.exercise) ?? exercise,
                battleID: battleID,
                startedAt: startedAt,
                completionReps: session.completionReps,
                battleDurationSeconds: session.battleDurationSeconds
            )
        } catch {
            let failure = WorkoutError.from(error)
            print("[Workout] Start failed: \(failure)")
            // Regular workouts have nothing to recover. Battle runs keep their ID for a retry
            // unless the server definitively refused the run.
            if battleID == nil || failure == .battleClosed || failure == .battleRunUsed {
                remove(record.id)
            }
            throw failure
        }
    }

    // MARK: - Checkpoints

    /// Saves the current counts to disk. Called after every rep and on a heartbeat.
    func checkpoint(id: UUID, reps: Int, blocks: Int) {
        guard var record = pending.first(where: { $0.id == id }), record.state == .active else { return }
        let now = Date()
        if reps != record.reps {
            record.lastRepAt = now
        }
        record.reps = reps
        record.blocks = blocks
        record.updatedAt = now
        upsert(record)
    }

    /// Discards a workout that ended with no reps; nothing is submitted.
    func abandon(id: UUID) {
        remove(id)
        if activeSessionID == id {
            activeSessionID = nil
        }
    }

    // MARK: - Finish & submit

    func finish(id: UUID, reps: Int, blocks: Int, reason: WorkoutEndReason) async -> SubmitState {
        guard var record = pending.first(where: { $0.id == id }) else {
            return .dropped("This workout couldn't be found on this phone.")
        }
        record.reps = reps
        record.blocks = blocks
        record.state = .ended
        record.endReason = reason.rawValue
        record.endedAt = Date()
        record.updatedAt = Date()
        upsert(record)
        if activeSessionID == id {
            activeSessionID = nil
        }
        return await submit(record)
    }

    /// Retries one specific workout (results screen "Try again").
    func retry(id: UUID) async -> SubmitState {
        guard let record = pending.first(where: { $0.id == id }) else {
            return .dropped("This workout was already saved.")
        }
        return await submit(record)
    }

    /// Recovers interrupted workouts and retries unsent ones. Runs at sign-in,
    /// on launch and whenever the app returns to the foreground.
    func syncPending() async {
        guard userID != nil, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        for record in pending where record.id != activeSessionID {
            var record = record
            switch record.state {
            case .registering:
                let isStale = record.createdAt < Date().addingTimeInterval(-2 * 24 * 3600)
                if record.battleID == nil || isStale {
                    remove(record.id)
                }
                continue
            case .active:
                // The app closed mid-workout: save what was reached as an interrupted workout.
                record.state = .ended
                record.endReason = WorkoutEndReason.interrupted.rawValue
                record.endedAt = record.lastRepAt ?? record.updatedAt
                upsert(record)
                print("[Workout] Recovering interrupted session \(record.id) with \(record.reps) reps")
            case .ended:
                break
            }
            if case .queued = await submit(record) {
                break
            }
        }
    }

    private func submit(_ record: PendingSession) async -> SubmitState {
        do {
            let outcome: WorkoutOutcomeDTO = try await Backend.client
                .rpc(
                    "complete_workout_session",
                    params: CompleteSessionParams(
                        sessionID: record.id,
                        reps: record.reps,
                        blocks: record.blocks,
                        endReason: record.endReason ?? WorkoutEndReason.finished.rawValue,
                        clientEndedAt: record.endedAt
                    )
                )
                .execute()
                .value
            remove(record.id)
            print("[Workout] Accepted session \(record.id): \(outcome.reps) reps, +\(outcome.coinsAwarded) coins")
            onAccepted?(outcome)
            return .saved(outcome)
        } catch {
            if BackendFailure.isOffline(error) {
                print("[Workout] Offline; session \(record.id) queued")
                return .queued
            }
            switch BackendFailure.code(error) {
            case "session_expired":
                remove(record.id)
                return .dropped("This workout is more than 7 days old, so it can no longer be saved.")
            case "session_not_found":
                remove(record.id)
                return .dropped("This workout wasn't registered with your account, so it can't be saved.")
            default:
                print("[Workout] Submit failed, will retry: \(error.localizedDescription)")
                return .queued
            }
        }
    }

    // MARK: - Persistence

    private func upsert(_ record: PendingSession) {
        if let index = pending.firstIndex(where: { $0.id == record.id }) {
            pending[index] = record
        } else {
            pending.append(record)
        }
        persist()
    }

    private func remove(_ id: UUID) {
        pending.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let userID else { return }
        let url = Self.fileURL(userID: userID)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pending.filter { $0.userID == userID })
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("[Workout] Failed to save pending workouts: \(error.localizedDescription)")
        }
    }

    private static func load(userID: UUID) -> [PendingSession] {
        guard let data = try? Data(contentsOf: fileURL(userID: userID)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = (try? decoder.decode([PendingSession].self, from: data)) ?? []
        return records.filter { $0.userID == userID }
    }

    private static func fileURL(userID: UUID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("PendingWorkouts", isDirectory: true)
            .appendingPathComponent("\(userID.uuidString.lowercased()).json")
    }
}
