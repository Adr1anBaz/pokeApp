import AVFoundation
import SwiftUI

struct BattleState: Codable {
    let battleNumber: Int
    let status: String
    let currentPokemon: CurrentPokemon
    let score: Score
    let winner: String?
    let lastTurn: LastTurn?
}

struct CurrentPokemon: Codable {
    let player1: BattlePokemon
    let player2: BattlePokemon
}

struct BattlePokemon: Codable {
    let pokemonId: Int
    let name: String
    let hp: Int
    let maxHp: Int
    let moves: [Move]
}

struct Move: Codable, Identifiable {
    let id: Int
    let name: String
    let power: Int
    let accuracy: Int
    let type: String
    let damageClass: String
}

struct Score: Codable {
    let player1: Int
    let player2: Int
}

struct LastTurn: Codable {
    let player1Move: String
    let player2Move: String
    let damageToPlayer1: Int
    let damageToPlayer2: Int
    let logs: [String]
}

struct BattleView: View {
    @ObservedObject var config: AppConfig
    @ObservedObject private var audio = AudioManager.shared
    @State private var battle: BattleState?
    @State private var message = ""
    @State private var isSendingMove = false
    @State private var showLeaveConfirmation = false
    @State private var hasReceivedBattle = false
    @State private var lastTurnFingerprint = ""
    @State private var displayedOwnHP: Int?
    @State private var displayedOpponentHP: Int?
    @State private var queuedCues: [BattleTurnCue] = []
    @State private var isAnimatingTurn = false
    @State private var animatedDialogue: String?
    @State private var dialogueGeneration = 0
    @State private var ownAttackOffset: CGFloat = 0
    @State private var opponentAttackOffset: CGFloat = 0
    @State private var ownImpact = false
    @State private var opponentImpact = false
    @State private var effect: BattleEffect?
    @State private var hasPlayedVictory = false

    private let pollingTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    private var ownPokemon: BattlePokemon? {
        guard let battle else { return nil }
        return config.playerSlot == 2 ? battle.currentPokemon.player2 : battle.currentPokemon.player1
    }

    private var opponentPokemon: BattlePokemon? {
        guard let battle else { return nil }
        return config.playerSlot == 2 ? battle.currentPokemon.player1 : battle.currentPokemon.player2
    }

    var body: some View {
        Group {
            if let battle, let winner = battle.winner {
                ResultView(config: config, winner: winner, score: battle.score)
            } else {
                battleScreen
            }
        }
        .navigationTitle("Combate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    audio.toggleMute()
                } label: {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .accessibilityLabel(audio.isMuted ? "Activar sonido" : "Silenciar sonido")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Salir") {
                    showLeaveConfirmation = true
                }
            }
        }
        .confirmationDialog("¿Salir de la sala?", isPresented: $showLeaveConfirmation) {
            Button("Salir", role: .destructive) {
                RoomActions.leave(config: config) { error in
                    if let error {
                        message = "Error: \(error)"
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .onAppear {
            fetchBattle()
        }
        .onReceive(pollingTimer) { _ in
            fetchBattle()
        }
    }

    private var battleScreen: some View {
        GeometryReader { geometry in
            ZStack {
                BattleFieldBackground()

                if let battle, let ownPokemon, let opponentPokemon {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            battleHeader(battle)
                            battleField(ownPokemon: ownPokemon, opponentPokemon: opponentPokemon)
                                .frame(height: min(max(geometry.size.height * 0.38, 240), 320))
                            battleControls(battle: battle, pokemon: ownPokemon)
                        }
                        .frame(maxWidth: 430)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                } else {
                    ProgressView("Preparando el combate...")
                        .font(DSFont.body(16, weight: .bold))
                        .tint(DSColor.ink)
                        .padding(22)
                        .background(DSColor.paper, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func battleHeader(_ battle: BattleState) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("COMBATE \(battle.battleNumber) DE 3")
                    .font(DSFont.title(10))
                Text("TÚ \(ownScore(battle))  ·  \(opponentScore(battle)) RIVAL")
                    .font(DSFont.body(12, weight: .bold))
            }
            Spacer(minLength: 8)
            Text(battle.status == "waiting_moves" ? "TU TURNO" : "EN CURSO")
                .font(DSFont.body(10, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(DSColor.paper.opacity(0.88), in: Capsule())
        }
        .foregroundStyle(DSColor.ink)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func ownScore(_ battle: BattleState) -> Int {
        config.playerSlot == 2 ? battle.score.player2 : battle.score.player1
    }

    private func opponentScore(_ battle: BattleState) -> Int {
        config.playerSlot == 2 ? battle.score.player1 : battle.score.player2
    }

    private func battleField(ownPokemon: BattlePokemon, opponentPokemon: BattlePokemon) -> some View {
        ZStack {
            VStack {
                HStack {
                    PokemonHPBox(label: "RIVAL", pokemon: opponentPokemon, displayedHP: displayedOpponentHP)
                    Spacer(minLength: 74)
                }
                Spacer()
                HStack {
                    Spacer(minLength: 74)
                    PokemonHPBox(label: "TU POKÉMON", pokemon: ownPokemon, displayedHP: displayedOwnHP)
                }
            }
            .padding(.vertical, 12)

            VStack {
                HStack {
                    Spacer()
                    PokemonSprite(pokemon: opponentPokemon, isOpponent: true)
                    .frame(width: 112, height: 112)
                        .offset(x: opponentAttackOffset + (opponentImpact ? 8 : 0))
                        .opacity(opponentImpact ? 0.35 : 1)
                        .padding(.trailing, 13)
                        .padding(.top, 43)
                }
                Spacer()
                HStack {
                    PokemonSprite(pokemon: ownPokemon, isOpponent: false)
                    .frame(width: 138, height: 138)
                        .offset(x: ownAttackOffset + (ownImpact ? -8 : 0))
                        .opacity(ownImpact ? 0.35 : 1)
                        .padding(.leading, 6)
                    Spacer()
                }
            }
            if let effect {
                BattleMoveEffect(type: effect.type)
                    .offset(x: effect.fromOwn ? (effect.progress * 150 - 75) : (75 - effect.progress * 150), y: effect.fromOwn ? 42 : -42)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    private func battleControls(battle: BattleState, pokemon: BattlePokemon) -> some View {
        VStack(spacing: 10) {
            DSDialogueBox(text: animatedDialogue ?? dialogue(for: battle), speaker: battle.status == "waiting_moves" ? "ENTRENADOR" : nil)
                .frame(minHeight: 72)

            if battle.status == "waiting_moves" {
                MoveGrid(moves: pokemon.moves, isDisabled: isSendingMove, action: sendMove)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: battle.status == "resolving" ? "arrow.triangle.2.circlepath" : "flag.checkered")
                    Text(battle.status == "resolving" ? "Movimiento enviado · esperando al rival" : "El combate ha terminado")
                }
                .font(DSFont.body(15, weight: .bold))
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(DSColor.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
            }

            if let logs = battle.lastTurn?.logs, let latest = logs.last, battle.status != "waiting_moves" {
                Text("ÚLTIMO TURNO · \(latest)")
                    .font(DSFont.body(11, weight: .bold))
                    .foregroundStyle(DSColor.paper)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !message.isEmpty {
                Text(message)
                    .font(DSFont.body(12))
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dialogue(for battle: BattleState) -> String {
        if let lastTurn = battle.lastTurn, let latest = lastTurn.logs.last {
            return latest
        }
        switch battle.status {
        case "waiting_moves": return "¿Qué debería hacer tu Pokémon?"
        case "resolving": return "Los movimientos están resolviéndose..."
        default: return "El combate está listo."
        }
    }

    private func fetchBattle() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/battle") else {
            message = "URL de batalla inválida"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    message = error.localizedDescription
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data,
                      let decoded = try? JSONDecoder().decode(BattleState.self, from: data) else {
                    message = "No se pudo obtener la batalla"
                    return
                }

                receiveBattle(decoded)
                message = ""
            }
        }.resume()
    }

    private func receiveBattle(_ decoded: BattleState) {
        let own = config.playerSlot == 2 ? decoded.currentPokemon.player2 : decoded.currentPokemon.player1
        let opponent = config.playerSlot == 2 ? decoded.currentPokemon.player1 : decoded.currentPokemon.player2
        let fingerprint = turnFingerprint(for: decoded, ownHP: own.hp, opponentHP: opponent.hp)

        guard hasReceivedBattle else {
            hasReceivedBattle = true
            lastTurnFingerprint = fingerprint
            displayedOwnHP = own.hp
            displayedOpponentHP = opponent.hp
            battle = decoded
            audio.playCry(named: own.name)
            return
        }

        let isNewTurn = fingerprint != lastTurnFingerprint
        battle = decoded
        if decoded.winner != nil, !hasPlayedVictory {
            hasPlayedVictory = true
            audio.play(.victory)
        }
        if isNewTurn {
            lastTurnFingerprint = fingerprint
            enqueueCues(for: decoded, own: own, opponent: opponent)
        } else if !isAnimatingTurn && queuedCues.isEmpty {
            displayedOwnHP = own.hp
            displayedOpponentHP = opponent.hp
        }
    }

    private func turnFingerprint(for battle: BattleState, ownHP: Int, opponentHP: Int) -> String {
        let turn = battle.lastTurn
        return "\(turn?.player1Move ?? "")|\(turn?.player2Move ?? "")|\(turn?.damageToPlayer1 ?? 0)|\(turn?.damageToPlayer2 ?? 0)|\(turn?.logs.joined(separator: "~") ?? "")|\(ownHP)|\(opponentHP)"
    }

    private func enqueueCues(for battle: BattleState, own: BattlePokemon, opponent: BattlePokemon) {
        guard let turn = battle.lastTurn else {
            displayedOwnHP = own.hp
            displayedOpponentHP = opponent.hp
            return
        }
        let ownIsPlayer1 = config.playerSlot != 2
        let ownMove = ownIsPlayer1 ? turn.player1Move : turn.player2Move
        let opponentMove = ownIsPlayer1 ? turn.player2Move : turn.player1Move
        let damageToOpponent = ownIsPlayer1 ? turn.damageToPlayer2 : turn.damageToPlayer1
        let damageToOwn = ownIsPlayer1 ? turn.damageToPlayer1 : turn.damageToPlayer2
        if !ownMove.isEmpty { queuedCues.append(BattleTurnCue(attackerIsOwn: true, move: ownMove, type: moveType(named: ownMove, in: own.moves), damagesTarget: damageToOpponent > 0)) }
        if !opponentMove.isEmpty { queuedCues.append(BattleTurnCue(attackerIsOwn: false, move: opponentMove, type: moveType(named: opponentMove, in: opponent.moves), damagesTarget: damageToOwn > 0)) }
        if queuedCues.isEmpty {
            displayedOwnHP = own.hp
            displayedOpponentHP = opponent.hp
        } else {
            playNextCue()
        }
    }

    private func moveType(named name: String, in moves: [Move]) -> String {
        moves.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.type ?? "normal"
    }

    private func playNextCue() {
        guard !isAnimatingTurn, !queuedCues.isEmpty else { return }
        let cue = queuedCues.removeFirst()
        isAnimatingTurn = true
        let attacker = cue.attackerIsOwn ? (ownPokemon?.name ?? "Tu Pokémon") : (opponentPokemon?.name ?? "El rival")
        typewrite("\(attacker) usó \(cue.move.uppercased())!")
        withAnimation(.easeOut(duration: 0.22)) {
            if cue.attackerIsOwn { ownAttackOffset = 24 } else { opponentAttackOffset = -24 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeIn(duration: 0.16)) { self.effect = BattleEffect(type: cue.type, fromOwn: cue.attackerIsOwn, progress: 1) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            guard cue.damagesTarget else { return }
            self.audio.play(.hit)
            withAnimation(.linear(duration: 0.09).repeatCount(4, autoreverses: true)) {
                if cue.attackerIsOwn { self.opponentImpact = true } else { self.ownImpact = true }
            }
            withAnimation(.easeOut(duration: 0.65)) {
                if cue.attackerIsOwn { self.displayedOpponentHP = self.opponentPokemon?.hp } else { self.displayedOwnHP = self.ownPokemon?.hp }
            }
            let targetHP = cue.attackerIsOwn ? self.opponentPokemon?.hp : self.ownPokemon?.hp
            if targetHP == 0 { self.audio.play(.faint) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            withAnimation(.easeOut(duration: 0.18)) {
                self.ownAttackOffset = 0; self.opponentAttackOffset = 0; self.ownImpact = false; self.opponentImpact = false; self.effect = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.08) {
            self.isAnimatingTurn = false
            if self.queuedCues.isEmpty { self.animatedDialogue = nil }
            self.playNextCue()
        }
    }

    private func typewrite(_ text: String) {
        dialogueGeneration += 1
        let generation = dialogueGeneration
        animatedDialogue = ""
        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.022) {
                guard generation == self.dialogueGeneration else { return }
                self.animatedDialogue?.append(character)
            }
        }
    }

    private func sendMove(moveId: Int) {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/battle/move") else {
            message = "URL de movimiento inválida"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "playerId": config.playerId,
            "moveId": moveId
        ])

        isSendingMove = true
        audio.play(.selection)
        message = "Movimiento enviado. Esperando al rival..."

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isSendingMove = false

                if let error {
                    message = "Error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    message = "Error: el servidor rechazó el movimiento"
                    return
                }
                audio.play(.confirmation)
            }
        }.resume()
    }
}

private struct PokemonHPBox: View {
    let label: String
    let pokemon: BattlePokemon
    let displayedHP: Int?

    private var currentHP: Int { displayedHP ?? pokemon.hp }

    private var health: Double {
        guard pokemon.maxHp > 0 else { return 0 }
        return Double(currentHP) / Double(pokemon.maxHp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DSFont.body(10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(pokemon.name.uppercased())
                .font(DSFont.body(16, weight: .bold))
                .lineLimit(1)
            HStack(spacing: 5) {
                Text("PS")
                    .font(DSFont.body(11, weight: .bold))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DSColor.ink.opacity(0.25))
                        Capsule().fill(DSColor.hp(for: health))
                            .frame(width: max(0, proxy.size.width * health))
                    }
                }
                .frame(height: 8)
            }
            Text("\(currentHP) / \(pokemon.maxHp)")
                .font(DSFont.body(11))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 166)
        .background(DSColor.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DSColor.ink, lineWidth: 3))
    }
}

private struct BattleTurnCue {
    let attackerIsOwn: Bool
    let move: String
    let type: String
    let damagesTarget: Bool
}

private struct BattleEffect: Equatable {
    let type: String
    let fromOwn: Bool
    let progress: CGFloat
}

private struct BattleMoveEffect: View {
    let type: String

    private var color: Color { DSColor.type(type) }
    private var icon: String {
        switch type.lowercased() {
        case "fire": return "flame.fill"
        case "water", "ice": return "drop.fill"
        case "electric": return "bolt.fill"
        case "grass", "bug": return "leaf.fill"
        case "psychic", "fairy", "ghost": return "sparkles"
        default: return "burst.fill"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 38, weight: .black))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 8)
    }
}

private struct PokemonSprite: View {
    let pokemon: BattlePokemon
    let isOpponent: Bool

    private var url: URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(pokemon.pokemonId).png")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.16))
                .frame(height: 25)
                .padding(.horizontal, 18)
                .offset(y: 4)
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else if phase.error != nil {
                    fallback
                } else {
                    ProgressView().tint(DSColor.ink)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(pokemon.name.capitalized)
        .accessibilityHint(isOpponent ? "Pokémon rival" : "Tu Pokémon")
    }

    private var fallback: some View {
        Image(systemName: "pawprint.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(DSColor.ink.opacity(0.55))
            .padding(30)
    }
}

private struct MoveGrid: View {
    let moves: [Move]
    let isDisabled: Bool
    let action: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
            ForEach(moves) { move in
                Button {
                    action(move.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(DSColor.type(move.type))
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(DSColor.ink.opacity(0.45), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(move.name.uppercased())
                                .font(DSFont.body(14, weight: .bold))
                                .lineLimit(1)
                            HStack {
                                Text(move.type.uppercased())
                                Spacer()
                                Text("PWR \(move.power) · \(move.accuracy)%")
                            }
                            .font(DSFont.body(9, weight: .bold))
                        }
                    }
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(DSColor.type(move.type).opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(DSColor.ink, lineWidth: 3))
                }
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.55 : 1)
            }
        }
    }
}

/// Reproduce respuestas breves sin depender de recursos de audio incluidos en la app.
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    enum Effect {
        case selection, confirmation, hit, faint, victory

        var tone: (frequency: Double, duration: Double) {
            switch self {
            case .selection: return (660, 0.06)
            case .confirmation: return (880, 0.10)
            case .hit: return (180, 0.09)
            case .faint: return (220, 0.32)
            case .victory: return (988, 0.24)
            }
        }
    }

    @Published private(set) var isMuted: Bool

    private let mutedKey = "battleAudioMuted"
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cryPlayer: AVPlayer?

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: mutedKey)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: mutedKey)
        if isMuted {
            player.stop()
            cryPlayer?.pause()
        }
    }

    func play(_ effect: Effect) {
        guard !isMuted, startEngineIfPossible() else { return }
        let tone = effect.tone
        let frames = AVAudioFrameCount(format.sampleRate * tone.duration)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            let progress = Double(index) / Double(frames)
            let envelope = sin(Double.pi * progress)
            samples[index] = Float(sin(2 * Double.pi * tone.frequency * Double(index) / format.sampleRate) * envelope * 0.22)
        }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    /// Los gritos son remotos y opcionales: si la red o el archivo fallan, AVPlayer no altera la interfaz.
    func playCry(named pokemonName: String) {
        let filename = pokemonName.lowercased()
            .replacingOccurrences(of: "♀", with: "-f")
            .replacingOccurrences(of: "♂", with: "-m")
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard !isMuted, !filename.isEmpty,
              let url = URL(string: "https://play.pokemonshowdown.com/audio/cries/" + filename + ".mp3") else { return }
        let player = AVPlayer(url: url)
        player.volume = 0.35
        cryPlayer = player
        player.play()
    }

    private func startEngineIfPossible() -> Bool {
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            return true
        } catch {
            return false
        }
    }
}

private struct BattleFieldBackground: View {
    var body: some View {
        LinearGradient(colors: [DSColor.skyTop, DSColor.skyBottom], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                ZStack {
                    Ellipse().fill(DSColor.grass).frame(width: 620, height: 260).offset(y: 110)
                    Ellipse().stroke(DSColor.grassDark.opacity(0.7), lineWidth: 3).frame(width: 440, height: 160).offset(y: 61)
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.yellow.opacity(0.8))
                    .padding(.trailing, 22)
                    .padding(.top, 18)
            }
    }
}

#Preview {
    NavigationStack {
        BattleView(config: AppConfig())
    }
}
