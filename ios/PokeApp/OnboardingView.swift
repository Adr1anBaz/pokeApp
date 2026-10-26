import SwiftUI

/// Scrollable column on the striped backdrop, shared by the menu screens.
struct MenuScreen<Content: View>: View {
    var top: Color = Color(hex: 0xE85040)
    var bottom: Color = Color(hex: 0xF8A040)
    let content: Content

    init(top: Color = Color(hex: 0xE85040), bottom: Color = Color(hex: 0xF8A040), @ViewBuilder content: () -> Content) {
        self.top = top
        self.bottom = bottom
        self.content = content()
    }

    var body: some View {
        StripedBackground(top: top, bottom: bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// POKé BATTLE logo with a bobbing Poké Ball.
struct GameLogo: View {
    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { context in
                // -6..6 over 1.1 s, back and forth
                let phase = sin(context.date.timeIntervalSinceReferenceDate / 1.1 * Double.pi)
                Pokeball(size: 64, rotation: phase * 12)
                    .offset(y: CGFloat(phase) * 6)
            }
            .frame(height: 76)
            OutlinedText(text: "POKé", font: PixelFont.title(40), width: 3.5)
            OutlinedText(text: "BATTLE", font: PixelFont.title(34), width: 3.5)
            Text("PvP")
                .font(PixelFont.headlineSmall)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Ds.blueDark))
                .padding(.top, 6)
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var vm: GameViewModel
    @State private var ip = ""
    @State private var name = ""

    var body: some View {
        MenuScreen {
            GameLogo().padding(.top, 12)
            DsPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("¡Bienvenido, Entrenador!")
                        .font(PixelFont.titleLarge)
                        .foregroundColor(Ds.ink)
                    Text("Escribe la IP de la computadora con el servidor. Ambos deben estar en la misma red WiFi.")
                        .font(PixelFont.bodyMedium)
                        .foregroundColor(Ds.inkSoft)
                    DsTextField(label: "IP del servidor", text: $ip, placeholder: "172.22.41.221",
                                keyboard: .numbersAndPunctuation, capitalization: .never)
                    if let url = GameViewModel.normalizeServerURL(ip) {
                        Text("▶ \(url)")
                            .font(PixelFont.bodySmall)
                            .foregroundColor(Ds.inkSoft)
                    }
                    DsTextField(label: "Tu nombre", text: $name, placeholder: "Ash")
                        .onChange(of: name) { value in
                            if value.count > 12 { name = String(value.prefix(12)) }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ErrorBanner(message: vm.error)
            PixelButton(text: vm.loading ? "CONECTANDO…" : "CONTINUAR", enabled: !vm.loading, sfx: .confirm) {
                vm.saveServer(ip, name: name)
            }
            if vm.connectionFailed {
                PixelButton(text: "GUARDAR IGUAL", color: Ds.frame, dark: Ds.ink, enabled: !vm.loading) {
                    vm.saveServer(ip, name: name, skipCheck: true)
                }
            }
            if vm.serverURL != nil {
                Button("Volver al lobby") { vm.backToLobby() }
                    .font(PixelFont.bodySmall)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            // Show the saved IP without the http:// and :3000 parts when coming back to change it.
            var saved = vm.serverURL ?? ""
            if saved.hasPrefix("http://") { saved.removeFirst("http://".count) }
            if saved.hasSuffix(":3000") { saved.removeLast(":3000".count) }
            ip = saved
            name = vm.playerName
        }
    }
}
