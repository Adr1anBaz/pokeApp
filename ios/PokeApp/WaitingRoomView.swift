import SwiftUI

struct RoomStatus: Codable {
    let roomCode: String
    let status: String
    let players: [PlayerStatus]
}

struct PlayerStatus: Codable {
    let playerId: String
    let name: String
    let ready: Bool
    let hasTeam: Bool
}

struct WaitingRoomView: View {
    @ObservedObject var config: AppConfig
    @State private var status: RoomStatus?
    @State private var errorMessage = ""
    @State private var showBattle = false
    @State private var showLeaveConfirmation = false
    @State private var roomNotFound = false

    private let pollingTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [DSColor.skyTop.opacity(0.58), DSColor.paper, DSColor.grass.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        roomHeader
                        codePanel
                        trainerLineup
                        nextStep

                        if !errorMessage.isEmpty {
                            DSDialogueBox(text: errorMessage, speaker: "AVISO")
                                .foregroundStyle(DSColor.red)
                        }

                        if roomNotFound {
                            DSButton(tone: .secondary) { config.clearRoom() } label: {
                                HStack(spacing: 8) { Text("▶"); Text("VOLVER AL LOBBY") }
                            }
                        }
                    }
                    .frame(maxWidth: 390)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Sala de enlace")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showBattle) { BattleView(config: config) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salir") { showLeaveConfirmation = true }
                        .font(DSFont.body(13, weight: .bold))
                        .foregroundStyle(DSColor.red)
                }
            }
            .confirmationDialog("¿Salir de la sala?", isPresented: $showLeaveConfirmation) {
                Button("Salir", role: .destructive) {
                    RoomActions.leave(config: config) { error in
                        if let error { errorMessage = error }
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .onAppear { fetchStatus() }
        .onReceive(pollingTimer) { _ in fetchStatus() }
    }

    private var roomHeader: some View {
        VStack(spacing: 6) {
            Text("SALA PREPARADA")
                .font(DSFont.title(18))
                .foregroundStyle(DSColor.ink)
            Text(status?.status == "battle" ? "¡COMIENZA EL COMBATE!" : "ESPERANDO ENTRENADORES")
                .font(DSFont.body(13, weight: .bold))
                .foregroundStyle(DSColor.red)
        }
    }

    private var codePanel: some View {
        DSPanel {
            VStack(spacing: 10) {
                Text("CÓDIGO DE SALA")
                    .font(DSFont.body(12, weight: .bold))
                    .foregroundStyle(DSColor.ink.opacity(0.68))
                HStack(spacing: 9) {
                    ForEach(roomCodeTiles.indices, id: \.self) { index in
                        Text(roomCodeTiles[index])
                            .font(DSFont.title(20))
                            .foregroundStyle(DSColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DSColor.yellow.opacity(0.38), in: RoundedRectangle(cornerRadius: 7))
                            .overlay { RoundedRectangle(cornerRadius: 7).stroke(DSColor.ink, lineWidth: 2) }
                    }
                }
                Text("Comparte este código con tu rival")
                    .font(DSFont.body(12))
                    .foregroundStyle(DSColor.ink.opacity(0.7))
            }
        }
    }

    private var roomCodeTiles: [String] {
        let code = Array(config.roomCode.uppercased()).map(String.init)
        return Array(code.prefix(4)) + Array(repeating: "—", count: max(0, 4 - code.count))
    }

    private var trainerLineup: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ENTRENADORES")
                    .font(DSFont.title(12))
                    .foregroundStyle(DSColor.ink)
                Spacer()
                Text("\(status?.players.count ?? 0)/2")
                    .font(DSFont.body(13, weight: .bold))
                    .foregroundStyle(DSColor.blue)
            }

            TrainerWaitingCard(player: currentPlayer, isCurrentPlayer: true)
            TrainerWaitingCard(player: rivalPlayer, isCurrentPlayer: false)
        }
    }

    private var currentPlayer: PlayerStatus? {
        status?.players.first { $0.playerId == config.playerId }
    }

    private var rivalPlayer: PlayerStatus? {
        status?.players.first { $0.playerId != config.playerId }
    }

    @ViewBuilder private var nextStep: some View {
        if let status {
            let currentPlayerNeedsTeam = currentPlayer?.hasTeam == false
            if status.players.count == 2 && currentPlayerNeedsTeam && status.status != "battle" {
                DSDialogueBox(text: "Tu rival está aquí. Elige tu equipo para continuar.", speaker: "PROF. OAK")
                NavigationLink {
                    TeamSelectionView(config: config)
                } label: {
                    HStack(spacing: 9) { Text("▶"); Text("ELEGIR EQUIPO") }
                }
                .buttonStyle(DSButtonStyle(tone: .primary))
            } else if status.players.count < 2 {
                DSDialogueBox(text: "Esperando a que un rival se una a la sala...", speaker: "SISTEMA")
            } else if currentPlayer?.hasTeam == true {
                DSDialogueBox(text: "Equipo listo. Espera a que ambos entrenadores se preparen.", speaker: "SISTEMA")
            }
        } else {
            DSDialogueBox(text: "Conectando con la sala...", speaker: "SISTEMA")
        }
    }

    private func fetchStatus() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)") else { errorMessage = "URL de sala inválida"; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error { DispatchQueue.main.async { errorMessage = error.localizedDescription }; return }
            guard let httpResponse = response as? HTTPURLResponse else { DispatchQueue.main.async { errorMessage = "No se pudo obtener el estado de la sala" }; return }
            if httpResponse.statusCode == 404 {
                DispatchQueue.main.async { status = nil; roomNotFound = true; errorMessage = "La sala ya no existe. Crea o únete a una sala nueva." }
                return
            }
            guard (200...299).contains(httpResponse.statusCode), let data, let decoded = try? JSONDecoder().decode(RoomStatus.self, from: data) else {
                DispatchQueue.main.async { errorMessage = "No se pudo obtener el estado de la sala" }; return
            }
            DispatchQueue.main.async {
                status = decoded; roomNotFound = false
                if decoded.status == "battle" { showBattle = true }
                errorMessage = ""
            }
        }.resume()
    }
}

private struct TrainerWaitingCard: View {
    let player: PlayerStatus?
    let isCurrentPlayer: Bool

    var body: some View {
        DSPanel {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: player == nil ? "person.fill.questionmark" : (isCurrentPlayer ? "person.fill" : "figure.walk"))
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(accent)
                }
                .frame(width: 58, height: 58)
                .overlay(Circle().stroke(DSColor.ink, lineWidth: 2))

                VStack(alignment: .leading, spacing: 5) {
                    Text(player?.name ?? "RIVAL BUSCADO...")
                        .font(DSFont.body(17, weight: .bold))
                        .foregroundStyle(player == nil ? DSColor.ink.opacity(0.52) : DSColor.ink)
                    Text(player == nil ? "La señal espera un rival" : statusText)
                        .font(DSFont.body(12, weight: .bold))
                        .foregroundStyle(player == nil ? DSColor.ink.opacity(0.58) : accent)
                }
                Spacer(minLength: 0)
                Text(player == nil ? "…" : (player!.ready ? "✓" : "▶"))
                    .font(DSFont.title(18))
                    .foregroundStyle(accent)
            }
        }
    }

    private var accent: Color { isCurrentPlayer ? DSColor.blue : DSColor.red }
    private var statusText: String {
        guard let player else { return "" }
        if player.ready { return "LISTO PARA LUCHAR" }
        return player.hasTeam ? "EQUIPO PREPARADO" : "ELIGIENDO EQUIPO"
    }
}

#Preview { WaitingRoomView(config: AppConfig()) }
