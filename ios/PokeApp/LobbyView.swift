import SwiftUI

struct LobbyView: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject private var sound = Sound.shared

    var body: some View {
        MenuScreen {
            GameLogo().padding(.top, 12)
            DsPanel(accent: Ds.red) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENTRENADOR")
                        .font(PixelFont.headlineSmall)
                        .foregroundColor(Ds.red)
                    DsTextField(label: "Tu nombre", text: Binding(
                        get: { vm.playerName },
                        set: { vm.updateName(String($0.prefix(12))) }
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ErrorBanner(message: vm.error)
            PixelButton(text: "CREAR SALA", enabled: !vm.loading, sfx: .confirm) { vm.createRoom() }
            PixelButton(text: "UNIRSE A SALA", color: Ds.blue, dark: Ds.blueDark, enabled: !vm.loading) { vm.openJoin() }
            if let code = vm.roomCode {
                PixelButton(text: "VOLVER A SALA \(code)", color: Ds.green, dark: Ds.greenDark) { vm.resumeRoom() }
            }
            HStack(spacing: 12) {
                Text("Servidor: \(vm.serverURL ?? "")")
                    .font(PixelFont.bodySmall)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SmallChip(text: "CAMBIAR IP") { vm.changeServer() }
                SmallChip(text: sound.muted ? "🔇" : "🔊") { sound.toggleMute() }
            }
            .padding(.top, 4)
        }
    }
}

struct SmallChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        PixelButton(text: text, color: Ds.ink.opacity(0.75), dark: Ds.ink, font: PixelFont.labelMedium, fullWidth: false, action: action)
            .fixedSize()
    }
}

struct JoinView: View {
    @ObservedObject var vm: GameViewModel
    @State private var code = ""

    var body: some View {
        MenuScreen(top: Ds.blueDark, bottom: Ds.blue) {
            OutlinedText(text: "UNIRSE", font: PixelFont.display, width: 3)
                .padding(.top, 24)
            DsPanel {
                VStack(spacing: 12) {
                    Text("Escribe el código de 4 letras")
                        .font(PixelFont.titleMedium)
                        .foregroundColor(Ds.ink)
                    CodeTiles(code: code.padding(toLength: 4, withPad: " ", startingAt: 0), animate: false)
                    DsTextField(label: "Código", text: $code, placeholder: "ABCD", capitalization: .characters)
                        .onChange(of: code) { value in
                            let clean = String(value.uppercased().filter { $0.isLetter }.prefix(4))
                            if clean != value { code = clean }
                        }
                    Text("Jugando como: \(vm.playerName)")
                        .font(PixelFont.bodyMedium)
                        .foregroundColor(Ds.inkSoft)
                }
                .frame(maxWidth: .infinity)
            }
            ErrorBanner(message: vm.error)
            PixelButton(text: vm.loading ? "UNIÉNDOSE…" : "¡ENTRAR!", enabled: !vm.loading && code.count == 4, sfx: .confirm) {
                vm.joinRoom(code)
            }
            PixelButton(text: "CANCELAR", color: Ds.frame, dark: Ds.ink) { vm.backToLobby() }
        }
    }
}

/// Room code shown as 4 letter tiles that pop in one by one.
struct CodeTiles: View {
    let code: String
    var animate: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(code.enumerated()), id: \.offset) { index, letter in
                CodeTile(letter: String(letter), delay: animate ? 0.15 * Double(index) : nil)
            }
        }
    }
}

private struct CodeTile: View {
    let letter: String
    let delay: Double?
    @State private var shown = false

    var body: some View {
        Text(letter)
            .font(PixelFont.display)
            .foregroundColor(Ds.yellow)
            .frame(width: 58, height: 70)
            .background(RoundedRectangle(cornerRadius: 10).fill(Ds.ink))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Ds.yellow, lineWidth: 3))
            .scaleEffect(shown || delay == nil ? 1 : 0.01)
            .onAppear {
                guard let delay else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(delay)) { shown = true }
            }
    }
}
