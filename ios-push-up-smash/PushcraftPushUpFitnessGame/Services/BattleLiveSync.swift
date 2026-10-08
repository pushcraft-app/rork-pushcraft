import Foundation
import Observation
import Supabase

/// Live rep sync for battle runs. Each phone broadcasts its current rep count
/// on a Supabase Realtime channel keyed to the battle ID, and both phones
/// listen — the gauge on the other side updates within a second of a rep.
///
/// The channel topic is the unguessable battle UUID, which doubles as access
/// control: only phones running that battle know which channel to join. If the
/// opponent's signal drops, their side simply holds at the last count received.
@MainActor
@Observable
final class BattleLiveSync {
    /// Opponent's latest reported reps. Starts at 0 and only moves forward.
    private(set) var opponentReps = 0
    /// True once any broadcast from the opponent arrived this run.
    private(set) var isOpponentLive = false

    @ObservationIgnored private var channel: RealtimeChannelV2?
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private var lastSentReps = -1

    /// Joins the battle's channel and starts listening for the opponent's reps.
    func connect(battleID: UUID) {
        guard channel == nil else { return }
        let channel = Backend.client.realtimeV2.channel(Self.topic(for: battleID))
        self.channel = channel

        let stream = channel.broadcastStream(event: Self.eventName)
        receiveTask = Task { [weak self] in
            for await payload in stream {
                guard let self, let reps = Self.reps(in: payload) else { continue }
                opponentReps = max(opponentReps, reps)
                isOpponentLive = true
            }
        }

        Task {
            // Registering the stream above already attached the listener, so
            // subscribing here starts delivery; failures just mean no live feed.
            try? await channel.subscribe()
        }
    }

    /// Broadcasts the local rep count. Only fires when the count changed.
    func send(reps: Int) {
        guard reps != lastSentReps, let channel else { return }
        lastSentReps = reps
        Task {
            await channel.broadcast(event: Self.eventName, message: ["reps": .integer(reps)])
        }
    }

    /// Leaves the channel and stops listening. Call when the arena closes.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        guard let channel else { return }
        self.channel = nil
        Task {
            await Backend.client.realtimeV2.removeChannel(channel)
        }
    }

    private static func topic(for battleID: UUID) -> String {
        "battle:\(battleID.uuidString.lowercased())"
    }

    private static let eventName = "reps"

    private static func reps(in payload: JSONObject) -> Int? {
        guard let value = payload["reps"] else { return nil }
        if let int = value.intValue { return int }
        if let double = value.doubleValue { return Int(double) }
        return nil
    }
}
