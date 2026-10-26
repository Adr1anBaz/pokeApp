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
    @State private var showVS = false
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
            .navigationDestination(isPresented: $showVS) {
                BattleVSView(config: config, players: status?.players ?? []) {
                    showBattle = true
                }
            }
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
        DSPanel {
            HStack(spacing: 12) {
                Image(systemName: roomStatusIcon)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(roomStatusColor)
                    .frame(width: 36, height: 36)
                    .background(roomStatusColor.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text("SALA DE ENLACE")
                        .font(DSFont.title(14))
                        .foregroundStyle(DSColor.ink)
                    Text(roomStatusLabel)
                        .font(DSFont.body(13, weight: .bold))
                        .foregroundStyle(roomStatusColor)
                }
                Spacer(minLength: 0)
            }
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
        DSPanel {
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
                DSDialogueBox(text: currentPlayer?.ready == true ? "Tu equipo está listo. Espera a que tu rival se prepare." : "Equipo enviado. Preparando tu estado para luchar...", speaker: "SISTEMA")
            }
        } else {
            DSDialogueBox(text: "Conectando con la sala...", speaker: "SISTEMA")
        }
    }

    private var roomStatusLabel: String {
        guard let status else { return "CONECTANDO CON LA SALA" }
        if status.status == "battle" { return "¡COMIENZA EL COMBATE!" }
        if status.players.count < 2 { return "ESPERANDO A TU RIVAL" }
        return currentPlayer?.ready == true ? "LISTO PARA LUCHAR" : "AMBOS ENTRENADORES CONECTADOS"
    }

    private var roomStatusColor: Color {
        guard let status else { return DSColor.blue }
        if status.status == "battle" || currentPlayer?.ready == true { return DSColor.grassDark }
        return status.players.count < 2 ? DSColor.red : DSColor.blue
    }

    private var roomStatusIcon: String {
        guard let status else { return "arrow.triangle.2.circlepath" }
        if status.status == "battle" { return "bolt.fill" }
        return status.players.count < 2 ? "person.badge.clock" : "person.2.fill"
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
                if decoded.status == "battle" { showVS = true }
                errorMessage = ""
            }
        }.resume()
    }
}

private struct TrainerWaitingCard: View {
    let player: PlayerStatus?
    let isCurrentPlayer: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Image(systemName: player == nil ? "person.fill.questionmark" : (isCurrentPlayer ? "person.fill" : "figure.walk"))
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)
            .overlay(Circle().stroke(DSColor.ink, lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text(player?.name ?? "RIVAL BUSCADO...")
                    .font(DSFont.body(16, weight: .bold))
                    .foregroundStyle(player == nil ? DSColor.ink.opacity(0.52) : DSColor.ink)
                Text(player == nil ? "La señal espera un rival" : statusText)
                    .font(DSFont.body(11, weight: .bold))
                    .foregroundStyle(player == nil ? DSColor.ink.opacity(0.58) : accent)
            }
            Spacer(minLength: 0)
            Text(player == nil ? "…" : (player!.ready ? "✓" : "▶"))
                .font(DSFont.title(16))
                .foregroundStyle(accent)
        }
        .padding(10)
        .background(DSColor.mist.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DSColor.ink.opacity(0.5), lineWidth: 1.5) }
    }

    private var accent: Color { isCurrentPlayer ? DSColor.blue : DSColor.red }
    private var statusText: String {
        guard let player else { return "" }
        if player.ready { return "LISTO PARA LUCHAR" }
        return player.hasTeam ? "EQUIPO PREPARADO" : "ELIGIENDO EQUIPO"
    }
}

#Preview { WaitingRoomView(config: AppConfig()) }
struct BattleVSView: View {
    @ObservedObject var config: AppConfig
    let players: [PlayerStatus]
    let onComplete: () -> Void

    @State private var hasEntered = false
    @State private var hasCompleted = false

    private var localPlayer: PlayerStatus? {
        players.first { $0.playerId == config.playerId }
    }

    private var rivalPlayer: PlayerStatus? {
        players.first { $0.playerId != config.playerId }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VSBackdrop()

                VStack(spacing: 0) {
                    trainerCard(player: rivalPlayer, isLocal: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(x: hasEntered ? 0 : proxy.size.width * 0.72)

                    Spacer(minLength: 0)

                    vsMark
                        .scaleEffect(hasEntered ? 1 : 0.15)
                        .opacity(hasEntered ? 1 : 0)

                    Spacer(minLength: 0)

                    trainerCard(player: localPlayer, isLocal: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: hasEntered ? 0 : -proxy.size.width * 0.72)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 34)
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden()
        .onAppear {
            withAnimation(.spring(response: 0.54, dampingFraction: 0.72).delay(0.12)) {
                hasEntered = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
                guard !hasCompleted else { return }
                hasCompleted = true
                onComplete()
            }
        }
    }

    private var vsMark: some View {
        Text("VS")
            .font(DSFont.title(48))
            .foregroundStyle(DSColor.yellow)
            .shadow(color: DSColor.ink, radius: 0, x: 4, y: 4)
            .shadow(color: DSColor.paper.opacity(0.65), radius: 0, x: -1, y: -1)
            .accessibilityLabel("Versus")
    }

    private func trainerCard(player: PlayerStatus?, isLocal: Bool) -> some View {
        VStack(alignment: isLocal ? .leading : .trailing, spacing: 6) {
            TrainerPortrait(player: player, isLocal: isLocal)
                .frame(width: 166, height: 166)
                .shadow(color: DSColor.ink.opacity(0.45), radius: 0, x: 5, y: 6)

            Text(isLocal ? "TÚ" : "RIVAL")
                .font(DSFont.title(10))
                .foregroundStyle(DSColor.paper.opacity(0.9))
            Text((player?.name ?? (isLocal ? "ENTRENADOR" : "RIVAL")).uppercased())
                .font(DSFont.title(15))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(DSColor.paper)
                .shadow(color: DSColor.ink, radius: 0, x: 2, y: 2)
        }
    }
}

private struct TrainerPortrait: View {
    let player: PlayerStatus?
    let isLocal: Bool

    private var spriteURL: URL? {
        // Pokémon Showdown sirve sprites de entrenadores y permite conservar esta vista sin datos nuevos del servidor.
        URL(string: "https://play.pokemonshowdown.com/sprites/trainers/\(isLocal ? "red" : "leaf").png")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill((isLocal ? DSColor.blue : DSColor.red).opacity(0.35))
                .overlay(Circle().stroke(DSColor.paper, lineWidth: 4))
            AsyncImage(url: spriteURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(8)
                } else if phase.error != nil {
                    fallback
                } else {
                    ProgressView().tint(DSColor.paper)
                }
            }
        }
        .accessibilityLabel("Entrenador \(player?.name ?? (isLocal ? "local" : "rival"))")
    }

    private var fallback: some View {
        Image(systemName: isLocal ? "person.crop.circle.fill" : "figure.walk.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(DSColor.paper)
            .padding(26)
    }
}

private struct VSBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DSColor.blue
                DiagonalPanel()
                    .fill(DSColor.red)
                DiagonalPanel()
                    .stroke(DSColor.paper.opacity(0.9), lineWidth: 5)
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(DSColor.paper.opacity(0.11))
                        .frame(width: proxy.size.width * 0.8, height: 9)
                        .rotationEffect(.degrees(-38))
                        .offset(x: CGFloat(index - 3) * 95, y: CGFloat(index - 3) * 72)
                }
            }
        }
    }
}

private struct DiagonalPanel: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.38, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.62, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        BattleVSView(config: AppConfig(), players: [
            PlayerStatus(playerId: "1", name: "Adrián", ready: true, hasTeam: true),
            PlayerStatus(playerId: "2", name: "Misty", ready: true, hasTeam: true)
        ], onComplete: {})
    }
}
