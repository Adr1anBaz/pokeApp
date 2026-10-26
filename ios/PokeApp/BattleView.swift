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
    @State private var battle: BattleState?
    @State private var message = ""
    @State private var isSendingMove = false
    @State private var showLeaveConfirmation = false

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
                    VStack(spacing: 0) {
                        battleHeader(battle)
                        battleField(ownPokemon: ownPokemon, opponentPokemon: opponentPokemon)
                            .frame(height: max(geometry.size.height * 0.48, 300))
                        battleControls(battle: battle, pokemon: ownPokemon)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                } else {
                    ProgressView("Preparando el combate...")
                        .font(DSFont.body(16, weight: .bold))
                        .tint(DSColor.ink)
                        .padding(22)
                        .background(DSColor.paper, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func battleHeader(_ battle: BattleState) -> some View {
        HStack {
            Text("COMBATE \(battle.battleNumber)")
                .font(DSFont.title(11))
            Spacer()
            Text("\(battle.score.player1)  -  \(battle.score.player2)")
                .font(DSFont.body(15, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DSColor.paper.opacity(0.82), in: Capsule())
        }
        .foregroundStyle(DSColor.ink)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func battleField(ownPokemon: BattlePokemon, opponentPokemon: BattlePokemon) -> some View {
        ZStack {
            VStack {
                HStack {
                    PokemonHPBox(label: "RIVAL", pokemon: opponentPokemon)
                    Spacer(minLength: 74)
                }
                Spacer()
                HStack {
                    Spacer(minLength: 74)
                    PokemonHPBox(label: "TU POKÉMON", pokemon: ownPokemon)
                }
            }
            .padding(.vertical, 20)

            VStack {
                HStack {
                    Spacer()
                    PokemonSprite(pokemon: opponentPokemon, isOpponent: true)
                        .frame(width: 128, height: 128)
                        .padding(.trailing, 13)
                        .padding(.top, 43)
                }
                Spacer()
                HStack {
                    PokemonSprite(pokemon: ownPokemon, isOpponent: false)
                        .frame(width: 154, height: 154)
                        .padding(.leading, 6)
                    Spacer()
                }
            }
        }
    }

    private func battleControls(battle: BattleState, pokemon: BattlePokemon) -> some View {
        VStack(spacing: 10) {
            DSDialogueBox(text: dialogue(for: battle), speaker: battle.status == "waiting_moves" ? "ENTRENADOR" : nil)
                .frame(minHeight: 78)

            if battle.status == "waiting_moves" {
                MoveGrid(moves: pokemon.moves, isDisabled: isSendingMove, action: sendMove)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: battle.status == "resolving" ? "arrow.triangle.2.circlepath" : "flag.checkered")
                    Text(battle.status == "resolving" ? "Esperando el turno rival..." : "El combate ha terminado")
                }
                .font(DSFont.body(15, weight: .bold))
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(DSColor.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
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

                battle = decoded
                message = ""
            }
        }.resume()
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
            }
        }.resume()
    }
}

private struct PokemonHPBox: View {
    let label: String
    let pokemon: BattlePokemon

    private var health: Double {
        guard pokemon.maxHp > 0 else { return 0 }
        return Double(pokemon.hp) / Double(pokemon.maxHp)
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
            Text("\(pokemon.hp) / \(pokemon.maxHp)")
                .font(DSFont.body(11))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 174)
        .background(DSColor.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DSColor.ink, lineWidth: 3))
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(move.name.uppercased())
                            .font(DSFont.body(14, weight: .bold))
                            .lineLimit(1)
                        HStack {
                            Text(move.type.uppercased())
                            Spacer()
                            Text("PWR \(move.power)")
                        }
                        .font(DSFont.body(9, weight: .bold))
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
