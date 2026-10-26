import SwiftUI

struct OnboardingView: View {
    @ObservedObject var config: AppConfig
    @State private var ip = ""

    private var cleanIP: String {
        ip.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DSColor.skyTop.opacity(0.72), DSColor.paper, DSColor.yellow.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 22)

                VStack(spacing: 8) {
                    Text("POKÉMON ARENA")
                        .font(DSFont.title(20))
                        .foregroundStyle(DSColor.ink)
                        .multilineTextAlignment(.center)
                    Text("PREPARA TU CONEXIÓN LOCAL")
                        .font(DSFont.body(14, weight: .bold))
                        .foregroundStyle(DSColor.red)
                }

                DSPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("▶")
                                .font(DSFont.body(17, weight: .bold))
                                .foregroundStyle(DSColor.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("¡Hola, Entrenador!")
                                    .font(DSFont.body(18, weight: .bold))
                                Text("Introduce la IP del servidor para empezar a jugar.")
                                    .font(DSFont.body(14))
                            }
                        }

                        DSInput(label: "IP DEL SERVIDOR", placeholder: "Ej: 172.22.41.221", text: $ip, fill: DSColor.skyTop.opacity(0.22))
#if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
#endif
                    }
                }

                DSButton {
                    config.serverURL = "http://\(cleanIP):3000"
                } label: {
                    HStack(spacing: 9) {
                        Text("▶")
                        Text("CONTINUAR")
                    }
                }
                .disabled(cleanIP.isEmpty)
                .opacity(cleanIP.isEmpty ? 0.55 : 1)

                Text("Ambos jugadores deben estar en la misma red Wi‑Fi")
                    .font(DSFont.body(12, weight: .bold))
                    .foregroundStyle(DSColor.ink.opacity(0.62))

                Spacer()
            }
            .frame(maxWidth: 390)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    OnboardingView(config: AppConfig())
}
