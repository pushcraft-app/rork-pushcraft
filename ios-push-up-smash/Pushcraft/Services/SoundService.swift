import AVFoundation

/// Low-latency SFX with per-play pitch via AVAudioEngine + varispeed.
/// Every voice passes through a gain stage so effects play well past the
/// 1.0 player-volume ceiling.
final class SoundService {
    enum Effect: String, CaseIterable {
        case hit = "punch_impact_crack"
        case shatter = "block_shatter_explosion"
        case coins = "arcade_coin_payout"
        case drop = "block_drop_thud"

        var voiceCount: Int { self == .hit ? 3 : 2 }
    }

    /// Master loudness lift (dB) applied to every effect.
    private static let boostDB: Float = 5

    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
        let gain: AVAudioUnitEQ
    }

    private let engine = AVAudioEngine()
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var voices: [Effect: [Voice]] = [:]
    private var cursor: [Effect: Int] = [:]

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SoundService: audio session error \(error.localizedDescription)")
        }

        for effect in Effect.allCases {
            guard let buffer = Self.load(effect) else { continue }
            buffers[effect] = buffer
            var pool: [Voice] = []
            for _ in 0..<effect.voiceCount {
                // A wide, near-flat parametric band that only adds the master
                // boost — player.volume caps at 1.0, this lifts past it.
                let gain = AVAudioUnitEQ(numberOfBands: 1)
                gain.bands[0].filterType = .parametric
                gain.bands[0].frequency = 1000
                gain.bands[0].bandwidth = 100
                gain.globalGain = Self.boostDB
                let voice = Voice(player: AVAudioPlayerNode(), varispeed: AVAudioUnitVarispeed(), gain: gain)
                engine.attach(voice.player)
                engine.attach(voice.varispeed)
                engine.attach(gain)
                engine.connect(voice.player, to: voice.varispeed, format: buffer.format)
                engine.connect(voice.varispeed, to: gain, format: buffer.format)
                engine.connect(gain, to: engine.mainMixerNode, format: buffer.format)
                pool.append(voice)
            }
            voices[effect] = pool
        }
        startIfNeeded()
    }

    /// - Parameters:
    ///   - pitch: varispeed rate (0.5...2). Lower = heavier.
    func play(_ effect: Effect, pitch: Float = 1, volume: Float = 1) {
        // Controlled by the Sound Effects preference on the Profile page.
        guard AppPreferences.shared.soundEnabled else { return }
        guard let buffer = buffers[effect], let pool = voices[effect], !pool.isEmpty else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        let index = cursor[effect, default: 0]
        cursor[effect] = (index + 1) % pool.count
        let voice = pool[index]
        voice.player.stop()
        voice.varispeed.rate = min(max(pitch, 0.5), 2)
        voice.player.volume = volume
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.player.play()
    }

    private func startIfNeeded() {
        guard !engine.isRunning, !buffers.isEmpty else { return }
        do {
            try engine.start()
        } catch {
            print("SoundService: engine start failed \(error.localizedDescription)")
        }
    }

    private static func load(_ effect: Effect) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("SoundService: failed to load \(effect.rawValue)")
            return nil
        }
    }
}
