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

            VStack(spacing: 22) {
                Spacer(minLength: 28)

                VStack(spacing: 8) {
                    Text("POKÉMON ARENA")
                        .font(DSFont.title(22))
                        .foregroundStyle(DSColor.ink)
                        .multilineTextAlignment(.center)
                    Text("CONEXIÓN LOCAL")
                        .font(DSFont.body(14, weight: .bold))
                        .foregroundStyle(DSColor.red)
                }

                DSPanel {
                    VStack(alignment: .leading, spacing: 16) {
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

                        VStack(alignment: .leading, spacing: 7) {
                            Text("IP DEL SERVIDOR")
                                .font(DSFont.body(12, weight: .bold))
                                .foregroundStyle(DSColor.ink.opacity(0.7))
                            TextField("Ej: 172.22.41.221", text: $ip)
                                .font(DSFont.body(16, weight: .bold))
                                .foregroundStyle(DSColor.ink)
                                .padding(12)
                                .background(DSColor.skyTop.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(DSColor.ink, lineWidth: 2)
                                }
#if os(iOS)
                                .keyboardType(.numbersAndPunctuation)
                                .textInputAutocapitalization(.never)
#endif
                        }
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

                Text("Modo inalámbrico local")
                    .font(DSFont.body(12, weight: .bold))
                    .foregroundStyle(DSColor.ink.opacity(0.62))

                Spacer()
            }
            .frame(maxWidth: 390)
            .padding(.horizontal, 22)
        }
    }
}

#Preview {
    OnboardingView(config: AppConfig())
}
