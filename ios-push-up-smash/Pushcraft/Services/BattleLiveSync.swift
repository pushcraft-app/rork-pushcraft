import Foundation
import Observation
import Supabase

/// Live link between the two phones in a battle, over a Supabase Realtime
/// broadcast channel keyed to the battle ID.
///
/// Protocol (all messages carry the sender's `role`, "host" or "guest"):
/// - `ready`: sent every second with the sender's readiness (calibrated and
///   holding the top). The host begins the shared 5-second countdown only once
///   BOTH phones report ready, so neither timer ever starts early or late.
/// - `reset`: the host restarts the countdown when either player loses
///   readiness before GO. Carries an `epoch`; stale messages are ignored.
/// - `start`: the host starts the countdown, then repeats `elapsed_ms` (time
///   since the countdown began) with its `epoch` every second. The guest
///   aligns to that, so phone clocks never need to match.
/// - `reps`: the current rep count, sent on every rep and repeated every
///   second, so a late join or a dropped message corrects itself within a second.
///
/// Every start/reset carries a monotonically increasing `epoch`; receivers
/// ignore anything older than the highest epoch they've seen, so a delayed old
/// start can never trigger GO after a countdown restart.
@MainActor
@Observable
final class BattleLiveSync {
    /// Opponent's latest reported reps. Only ever moves forward.
    private(set) var opponentReps = 0
    /// True once any message from the opponent arrived.
    private(set) var isOpponentPresent = false
    /// True while this phone is subscribed to the battle channel.
    private(set) var isConnected = false
    /// The opponent's latest readiness report.
    private(set) var isOpponentReady = false
    /// Local time the shared 5-second countdown began. Nil while waiting (or
    /// after a restart, until both phones are ready again).
    private(set) var startAnchor: Date?

    @ObservationIgnored private var channel: RealtimeChannelV2?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var isHost = false
    @ObservationIgnored private var battleDuration = 60
    @ObservationIgnored private var myReps = 0
    @ObservationIgnored private var lastSentReps = -1
    @ObservationIgnored private var loggedEvents: Set<String> = []
    @ObservationIgnored private var myReady = false
    @ObservationIgnored private var isSolo = false
    /// Epoch this phone increments when it starts or restarts the countdown.
    @ObservationIgnored private var epoch = 0
    /// Highest epoch seen from the opponent; older messages are stale.
    @ObservationIgnored private var maxSeenEpoch = -1

    private var myRole: String { isHost ? "host" : "guest" }

    /// Joins the battle channel, starts listening and starts the 1-second heartbeat.
    func connect(battleID: UUID, isHost: Bool, battleDuration: Int) {
        guard channel == nil else { return }
        self.isHost = isHost
        self.battleDuration = battleDuration
        let channel = Backend.client.realtimeV2.channel(Self.topic(for: battleID))
        self.channel = channel
        print("[BattleLive] Joining \(Self.topic(for: battleID)) as \(myRole)")

        // Streams must exist before subscribing so no early message is missed.
        for event in [Event.ready, Event.reset, Event.start, Event.reps] {
            let stream = channel.broadcastStream(event: event)
            tasks.append(Task { [weak self] in
                for await message in stream {
                    self?.handle(event: event, message: message)
                }
            })
        }
        tasks.append(Task { [weak self] in await self?.maintainConnection(channel) })
        tasks.append(Task { [weak self] in await self?.heartbeat() })
    }

    /// Starts the countdown without an opponent (they already played their
    /// run). The countdown still begins only once this phone is ready.
    func beginSolo() {
        guard startAnchor == nil else { return }
        isSolo = true
        maybeStart()
        print("[BattleLive] Opponent already played — waiting for local readiness")
    }

    /// Feeds the local readiness (calibrated, near the top, body visible) into
    /// the handshake. On the host, losing readiness during the shared countdown
    /// restarts it for both phones.
    func setReady(_ ready: Bool) {
        guard myReady != ready else { return }
        myReady = ready
        if !ready, isHost, let anchor = startAnchor, Date() < anchor.addingTimeInterval(Self.countdownSeconds) {
            restartCountdown()
        } else if ready {
            maybeStart()
        }
    }

    /// Records the local rep count and sends it right away when it changed.
    func update(reps: Int) {
        myReps = reps
        guard startAnchor != nil, reps != lastSentReps else { return }
        lastSentReps = reps
        send(Event.reps, ["reps": .integer(reps)])
        print("[BattleLive] Sent reps \(reps)")
    }

    /// Leaves the channel and stops all background work. Call when the arena closes.
    func disconnect() {
        tasks.forEach { $0.cancel() }
        tasks = []
        isConnected = false
        guard let channel else { return }
        self.channel = nil
        Task {
            await Backend.client.realtimeV2.removeChannel(channel)
        }
    }

    // MARK: - Starting

    /// The host opens the shared countdown once both phones report ready; a
    /// solo run starts on local readiness alone.
    private func maybeStart() {
        guard startAnchor == nil, myReady, isSolo || isOpponentReady else { return }
        epoch += 1
        startAnchor = Date()
        print("[BattleLive] Both players ready — host starts the countdown (epoch \(epoch))")
    }

    private func restartCountdown() {
        epoch += 1
        startAnchor = nil
        isOpponentReady = false
        send(Event.reset, ["epoch": .integer(epoch)])
        print("[BattleLive] Readiness lost — countdown restarted (epoch \(epoch))")
    }

    // MARK: - Connection

    private func maintainConnection(_ channel: RealtimeChannelV2) async {
        while !Task.isCancelled {
            if channel.status == .unsubscribed {
                try? await channel.subscribe()
            }
            let connected = channel.status == .subscribed
            if connected != isConnected {
                isConnected = connected
                print("[BattleLive] \(connected ? "Connected" : "Not connected yet")")
            }
            try? await Task.sleep(for: .seconds(connected ? 2 : 1))
        }
    }

    private func heartbeat() async {
        while !Task.isCancelled {
            send(Event.ready, ["ready": .bool(myReady)])
            if let startAnchor {
                let elapsed = Int(Date().timeIntervalSince(startAnchor) * 1000)
                send(Event.start, ["elapsed_ms": .integer(elapsed), "epoch": .integer(epoch)])
                lastSentReps = myReps
                send(Event.reps, ["reps": .integer(myReps)])
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func send(_ event: String, _ fields: JSONObject) {
        guard let channel, channel.status == .subscribed else { return }
        var message = fields
        message["role"] = .string(myRole)
        Task {
            await channel.broadcast(event: event, message: message)
        }
    }

    // MARK: - Receiving

    private func handle(event: String, message: JSONObject) {
        let body = Self.body(of: message)
        if body["role"]?.stringValue == myRole { return }

        if !loggedEvents.contains(event) {
            loggedEvents.insert(event)
            print("[BattleLive] First '\(event)' received from opponent")
        }
        isOpponentPresent = true

        switch event {
        case Event.ready:
            isOpponentReady = Self.bool(body["ready"])
            if isHost {
                if !isOpponentReady, let anchor = startAnchor,
                   Date() < anchor.addingTimeInterval(Self.countdownSeconds) {
                    // Opponent lowered during the countdown — restart it for both.
                    restartCountdown()
                } else if startAnchor == nil {
                    maybeStart()
                }
            }
        case Event.reset:
            guard let received = Self.int(body["epoch"]), received >= maxSeenEpoch else { return }
            maxSeenEpoch = received
            if startAnchor != nil {
                print("[BattleLive] Countdown restarted by host (epoch \(received))")
            }
            startAnchor = nil
        case Event.start:
            guard let received = Self.int(body["epoch"]), received >= maxSeenEpoch else { return }
            maxSeenEpoch = received
            guard let elapsed = Self.int(body["elapsed_ms"]) else { return }
            let peerAnchor = Date().addingTimeInterval(-Double(max(0, elapsed)) / 1000)
            if let current = startAnchor {
                // Only the guest re-aligns, and only before GO, so the
                // two phones never chase each other.
                let beforeGo = Date() < current.addingTimeInterval(Self.countdownSeconds)
                guard !isHost, beforeGo, abs(current.timeIntervalSince(peerAnchor)) > 0.75 else { return }
            } else {
                // Join a run already under way only if there's real time left.
                guard Double(elapsed) / 1000 < Self.countdownSeconds + Double(battleDuration) - 5 else { return }
            }
            startAnchor = peerAnchor
            print("[BattleLive] Countdown synced to opponent (\(elapsed) ms in, epoch \(received))")
        case Event.reps:
            guard let reps = Self.int(body["reps"]), reps > opponentReps else { return }
            opponentReps = reps
            print("[BattleLive] Opponent reps \(reps)")
        default:
            break
        }
    }

    /// Broadcast callbacks hand over the whole envelope
    /// (`{type, event, payload: {...}}`); the fields we sent live in `payload`.
    private static func body(of message: JSONObject) -> JSONObject {
        message["payload"]?.objectValue ?? message
    }

    private static func int(_ value: AnyJSON?) -> Int? {
        guard let value else { return nil }
        if let int = value.intValue { return int }
        if let double = value.doubleValue { return Int(double) }
        if let string = value.stringValue { return Int(string) }
        return nil
    }

    private static func bool(_ value: AnyJSON?) -> Bool {
        guard let value else { return false }
        if let bool = value.boolValue { return bool }
        if let int = value.intValue { return int != 0 }
        return value.stringValue == "true"
    }

    /// Length of the shared get-ready countdown before GO.
    static let countdownSeconds: TimeInterval = 5

    private static func topic(for battleID: UUID) -> String {
        "battle:\(battleID.uuidString.lowercased())"
    }

    private enum Event {
        static let ready = "ready"
        static let reset = "reset"
        static let start = "start"
        static let reps = "reps"
    }
}
