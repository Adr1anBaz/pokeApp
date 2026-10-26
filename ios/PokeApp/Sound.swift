import AVFoundation
import UIKit

/// Chiptune effects synthesized at startup; no audio files in the project.
enum Sfx: CaseIterable {
    case select, confirm, hit, superHit, weakHit, miss, faint, ballOpen, throwBall, join, victory, defeat, card
}

/// Sound effects (synthesized) and Pokémon cries (streamed). Port of android/.../audio/Sound.kt.
@MainActor
final class Sound: ObservableObject {
    static let shared = Sound()
    nonisolated private static let rate = 22050.0
    private static let mutedKey = "muted"

    @Published private(set) var muted: Bool

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Sound.rate, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Sfx: AVAudioPCMBuffer] = [:]
    private var cryFiles: [Int: URL] = [:]

    private init() {
        muted = UserDefaults.standard.bool(forKey: Self.mutedKey)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        for sfx in Sfx.allCases { buffers[sfx] = makeBuffer(Self.synth(sfx)) }
        engine.prepare()
        try? engine.start()
    }

    func toggleMute() {
        muted.toggle()
        UserDefaults.standard.set(muted, forKey: Self.mutedKey)
    }

    func play(_ sfx: Sfx) {
        guard !muted, let buffer = buffers[sfx], ensureRunning() else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Plays the Pokémon's cry. iOS can't decode PokeAPI's OGG cries, so the MP3 from
    /// Pokémon Showdown is used. A lower [pitch] is used when it faints.
    func cry(id: Int, name: String, pitch: Float = 1) {
        guard !muted else { return }
        Task {
            guard let file = await cryFile(id: id, name: name) else { return }
            playCry(file, pitch: pitch)
        }
    }

    private func playCry(_ url: URL, pitch: Float) {
        guard !muted, ensureRunning(), let file = try? AVAudioFile(forReading: url) else { return }
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        varispeed.rate = pitch
        engine.attach(player)
        engine.attach(varispeed)
        engine.connect(player, to: varispeed, format: file.processingFormat)
        engine.connect(varispeed, to: engine.mainMixerNode, format: file.processingFormat)
        player.volume = 0.6
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                player.stop()
                self.engine.detach(player)
                self.engine.detach(varispeed)
            }
        }
        player.play()
    }

    /// Downloads the cry once and keeps it in Caches. Showdown names have no hyphens
    /// ("mr-mime" -> "mrmime"); forms like "deoxys-normal" fall back to the base species.
    private func cryFile(id: Int, name: String) async -> URL? {
        if let url = cryFiles[id], FileManager.default.fileExists(atPath: url.path) { return url }
        guard let directory = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("cries", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("\(id).mp3")
        if FileManager.default.fileExists(atPath: destination.path) {
            cryFiles[id] = destination
            return destination
        }
        let clean = { (s: String) in s.lowercased().filter { $0.isLetter || $0.isNumber } }
        var candidates = [clean(name)]
        if let base = name.split(separator: "-").first.map(String.init), clean(base) != candidates[0] {
            candidates.append(clean(base))
        }
        for candidate in candidates {
            guard let url = URL(string: "https://play.pokemonshowdown.com/audio/cries/\(candidate).mp3"),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  !data.isEmpty else { continue }
            guard (try? data.write(to: destination, options: .atomic)) != nil else { return nil }
            cryFiles[id] = destination
            return destination
        }
        return nil
    }

    private func ensureRunning() -> Bool {
        if !engine.isRunning { try? engine.start() }
        return engine.isRunning
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, s) in samples.enumerated() { channel[i] = max(-1, min(1, s)) }
        return buffer
    }

    // MARK: - Synthesis

    private struct Builder {
        var data: [Float] = []

        /// Square-wave note sweeping from f0 to f1 Hz.
        mutating func tone(_ f0: Double, _ f1: Double? = nil, ms: Int, vol: Float = 0.35, duty: Double = 0.5) {
            let end = f1 ?? f0
            let n = Int(Sound.rate) * ms / 1000
            var phase = 0.0
            for i in 0..<n {
                let t = Double(i) / Double(n)
                phase += (f0 + (end - f0) * t) / Sound.rate
                let square: Float = phase.truncatingRemainder(dividingBy: 1) < duty ? 1 : -1
                let envelope = max(Float(1 - t), 0.15)
                data.append(square * vol * envelope)
            }
        }

        mutating func noise(_ ms: Int, vol: Float = 0.5, decay: Double = 5) {
            let n = Int(Sound.rate) * ms / 1000
            var held: Float = 0
            for i in 0..<n {
                if i % 3 == 0 { held = Float.random(in: -1...1) }
                data.append(held * vol * Float(exp(-decay * Double(i) / Double(n))))
            }
        }

        mutating func sine(_ f0: Double, _ f1: Double, ms: Int, vol: Float = 0.4) {
            let n = Int(Sound.rate) * ms / 1000
            var phase = 0.0
            for i in 0..<n {
                let t = Double(i) / Double(n)
                phase += (f0 + (f1 - f0) * t) / Sound.rate
                data.append(Float(sin(2 * Double.pi * phase)) * vol * Float(1 - t))
            }
        }

        mutating func rest(_ ms: Int) {
            data.append(contentsOf: [Float](repeating: 0, count: Int(Sound.rate) * ms / 1000))
        }
    }

    nonisolated private static func synth(_ sfx: Sfx) -> [Float] {
        var b = Builder()
        switch sfx {
        case .select: b.tone(1320, ms: 45, vol: 0.25)
        case .confirm: b.tone(880, ms: 60, vol: 0.25); b.tone(1320, ms: 90, vol: 0.25)
        case .card: b.noise(60, vol: 0.25, decay: 3); b.tone(660, 990, ms: 70, vol: 0.2)
        case .hit: b.noise(140, vol: 0.6); b.tone(180, 90, ms: 60, vol: 0.3)
        case .superHit: b.noise(90, vol: 0.7); b.rest(20); b.noise(180, vol: 0.8, decay: 4); b.tone(220, 70, ms: 90, vol: 0.35)
        case .weakHit: b.noise(90, vol: 0.3, decay: 7)
        case .miss: b.sine(900, 300, ms: 220, vol: 0.3)
        case .faint: b.tone(700, 110, ms: 650, vol: 0.3, duty: 0.25)
        case .throwBall: b.sine(300, 1200, ms: 260, vol: 0.3)
        case .ballOpen: b.noise(50, vol: 0.4, decay: 2); b.tone(523, 1568, ms: 160, vol: 0.25, duty: 0.25)
        case .join: b.tone(784, ms: 80); b.tone(988, ms: 80); b.tone(1175, ms: 160)
        case .victory:
            for f in [523.0, 659, 784, 1047] { b.tone(f, ms: 110, duty: 0.25) }
            b.rest(40); b.tone(784, ms: 110, duty: 0.25); b.tone(1047, ms: 380, duty: 0.25)
        case .defeat:
            for f in [659.0, 587, 523, 392] { b.tone(f, ms: 200, vol: 0.3, duty: 0.25) }
        }
        return b.data
    }
}

/// Vibration on hits (strong for super effective).
enum Haptics {
    @MainActor static func hit(strong: Bool) {
        UIImpactFeedbackGenerator(style: strong ? .heavy : .light).impactOccurred()
    }
}
