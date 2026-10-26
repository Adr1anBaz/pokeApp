import SwiftUI

private struct HistoryResponse: Codable {
    let total: Int
    let matches: [HistoryMatch]
}

private struct HistoryMatch: Codable, Identifiable {
    let id: String
    let players: [String]
    let winner: String
    let score: Score
    let date: String
}

struct ResultView: View {
    @ObservedObject var config: AppConfig
    let winner: String
    let score: Score
    @State private var history: [HistoryMatch] = []
    @State private var message = ""
    @State private var isShowingHistory = false
    @State private var animateParticles = false

    private var didWin: Bool {
        winner.caseInsensitiveCompare(config.playerName) == .orderedSame
    }

    private var outcomeTitle: String { didWin ? "¡VICTORIA!" : "DERROTA" }
    private var outcomeMessage: String {
        didWin ? "¡Tu equipo ha ganado el combate!" : "Tu rival se llevó esta vez la victoria."
    }
    private var opponentSummaryName: String { didWin ? "RIVAL" : winner.uppercased() }

    var body: some View {
        ZStack {
            resultBackground
            if didWin {
                CelebrationParticles(isAnimating: animateParticles)
                    .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    resultHeader
                    outcomePanel
                    scorePanel
                    playerSummary

                    DSButton(tone: .secondary) {
                        isShowingHistory.toggle()
                        if isShowingHistory && history.isEmpty { fetchHistory() }
                    } label: {
                        Label(isShowingHistory ? "OCULTAR HISTORIAL" : "VER HISTORIAL", systemImage: "clock.arrow.circlepath")
                    }

                    if isShowingHistory { historyPanel }

                    DSButton {
                        config.roomCode = ""
                        config.playerId = ""
                        config.playerSlot = 1
                    } label: {
                        Label("VOLVER AL LOBBY", systemImage: "house.fill")
                    }
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { animateParticles = true }
    }

    private var resultBackground: some View {
        LinearGradient(
            colors: didWin
                ? [DSColor.skyTop, DSColor.yellow.opacity(0.45), DSColor.grass.opacity(0.5)]
                : [DSColor.ink, DSColor.blue.opacity(0.55), DSColor.ink],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var resultHeader: some View {
        HStack {
            Text("RESULTADO FINAL")
                .font(DSFont.title(13))
            Spacer()
            Image(systemName: didWin ? "star.fill" : "flag.checkered")
                .font(.title3)
        }
        .foregroundStyle(didWin ? DSColor.ink : DSColor.paper)
        .padding(.top, 6)
    }

    private var outcomePanel: some View {
        DSPanel {
            VStack(spacing: 10) {
                Image(systemName: didWin ? "trophy.fill" : "bolt.horizontal.circle.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(didWin ? DSColor.yellow : DSColor.red)
                    .shadow(color: DSColor.ink.opacity(0.35), radius: 0, x: 2, y: 3)
                Text(outcomeTitle)
                    .font(DSFont.title(22))
                    .foregroundStyle(didWin ? DSColor.red : DSColor.blue)
                Text(outcomeMessage)
                    .font(DSFont.body(15, weight: .bold))
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
    }

    private var scorePanel: some View {
        HStack(spacing: 16) {
            scoreSide(title: "JUGADOR 1", score: score.player1, tint: DSColor.red)
            Text("VS")
                .font(DSFont.title(14))
                .foregroundStyle(DSColor.ink)
            scoreSide(title: "JUGADOR 2", score: score.player2, tint: DSColor.blue)
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(DSColor.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(DSColor.ink, lineWidth: 4) }
    }

    private func scoreSide(title: String, score: Int, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(title).font(DSFont.body(10, weight: .bold)).foregroundStyle(tint)
            Text("\(score)").font(DSFont.title(27)).foregroundStyle(DSColor.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var playerSummary: some View {
        DSDialogueBox(
            text: "\(config.playerName.uppercased()) VS \(opponentSummaryName)\nGANADOR: \(winner.uppercased())",
            speaker: "RESUMEN DE ENTRENADORES"
        )
    }

    @ViewBuilder private var historyPanel: some View {
        DSPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("ÚLTIMAS 10 PARTIDAS")
                    .font(DSFont.title(11))
                    .foregroundStyle(DSColor.blue)
                if history.isEmpty && message.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else if history.isEmpty {
                    Text(message).font(DSFont.body(14)).foregroundStyle(DSColor.ink)
                } else {
                    ForEach(history) { match in
                        HistoryRow(match: match)
                        if match.id != history.last?.id { Divider().overlay(DSColor.ink.opacity(0.2)) }
                    }
                }
            }
        }
    }

    private func fetchHistory() {
        guard let url = URL(string: "\(config.serverURL)/history") else {
            message = "URL de historial inválida"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    message = "Error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data,
                      let decoded = try? JSONDecoder().decode(HistoryResponse.self, from: data) else {
                    message = "No se pudo cargar el historial"
                    return
                }

                history = Array(decoded.matches.prefix(10))
                message = history.isEmpty ? "No hay partidas registradas" : ""
            }
        }.resume()
    }
}

private struct HistoryRow: View {
    let match: HistoryMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.players.joined(separator: " VS ").uppercased())
                    .font(DSFont.body(13, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text("\(match.score.player1)-\(match.score.player2)")
                    .font(DSFont.title(11))
                    .foregroundStyle(DSColor.red)
            }
            Text("GANÓ \(match.winner.uppercased())")
                .font(DSFont.body(11))
                .foregroundStyle(DSColor.ink.opacity(0.7))
        }
    }
}

private struct CelebrationParticles: View {
    let isAnimating: Bool
    private let colors: [Color] = [DSColor.red, DSColor.blue, DSColor.yellow, DSColor.grass]

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 2) ? 7 : 5, height: 11)
                    .rotationEffect(.degrees(isAnimating ? Double(index * 47) : 0))
                    .position(
                        x: CGFloat((index * 67) % max(Int(proxy.size.width), 1)),
                        y: isAnimating ? proxy.size.height + 25 : -20
                    )
                    .animation(.easeIn(duration: 1.5 + Double(index % 4) * 0.2).delay(Double(index) * 0.035), value: isAnimating)
            }
        }
        .ignoresSafeArea()
    }
}
