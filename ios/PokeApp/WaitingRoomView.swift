import SwiftUI

struct WaitingRoomView: View {
    @ObservedObject var vm: GameViewModel
    @State private var lastCount = 0

    private var players: [PlayerInfo] { vm.room?.players ?? [] }

    var body: some View {
        MenuScreen(top: Color(hex: 0x3050B0), bottom: Color(hex: 0x58A8E8)) {
            Text("CÓDIGO DE SALA")
                .font(PixelFont.headlineSmall)
                .foregroundColor(.white)
                .padding(.top, 16)
            CodeTiles(code: vm.roomCode ?? "????")
            Text("¡Compártelo con tu rival!")
                .font(PixelFont.titleMedium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            DsPanel(accent: Ds.yellow) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ENTRENADORES \(players.count)/2")
                        .font(PixelFont.headlineSmall)
                        .foregroundColor(Ds.ink)
                    ForEach(Array(players.enumerated()), id: \.element.playerId) { index, player in
                        TrainerRow(player: player, isYou: player.playerId == vm.playerId, isHost: index == 0)
                    }
                    if players.count < 2 {
                        HStack(spacing: 10) {
                            SpinningPokeball(size: 28)
                            Text("Esperando rival…")
                                .font(PixelFont.titleMedium)
                                .foregroundColor(Ds.inkSoft)
                        }
                    } else {
                        Text("¡Rival encontrado! Preparando equipos…")
                            .font(PixelFont.titleMedium)
                            .foregroundColor(Ds.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ErrorBanner(message: vm.error)
            PixelButton(text: "SALIR DE LA SALA", color: Ds.frame, dark: Ds.ink) { vm.leaveRoom() }
        }
        .onChange(of: players.count) { count in
            if count > lastCount && lastCount > 0 { Sound.shared.play(.join) }
            lastCount = count
        }
    }
}

struct TrainerRow: View {
    let player: PlayerInfo
    let isYou: Bool
    let isHost: Bool
    @State private var shown = false

    var body: some View {
        let (label, color): (String, Color) = player.ready ? ("¡LISTO!", Ds.green)
            : player.hasTeam ? ("EQUIPO OK", Ds.blue)
            : ("ELIGIENDO", Ds.inkSoft)
        HStack(spacing: 10) {
            Pokeball(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(player.name + (isYou ? " (tú)" : ""))
                    .font(PixelFont.titleMedium)
                    .foregroundColor(Ds.ink)
                Text(isHost ? "Anfitrión" : "Retador")
                    .font(PixelFont.bodySmall)
                    .foregroundColor(Ds.inkSoft)
            }
            Spacer(minLength: 0)
            Text(label)
                .font(PixelFont.labelMedium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(color))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill((isHost ? Ds.red : Ds.blue).opacity(0.12)))
        .offset(x: shown ? 0 : 400)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.35)) { shown = true } }
    }
}
