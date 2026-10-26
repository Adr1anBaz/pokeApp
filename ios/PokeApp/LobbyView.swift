import SwiftUI

private struct RoomResponse: Decodable {
    let roomCode: String
    let playerId: String
    let role: String?
}

private struct ServerError: Decodable {
    let error: String?
}

struct LobbyView: View {
    @ObservedObject var config: AppConfig
    @State private var name = ""
    @State private var joinCode = ""
    @State private var message = ""
    @State private var isLoading = false

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanJoinCode: String { joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

    var body: some View {
        ZStack {
            lobbyBackground
            ScrollView {
                VStack(spacing: 16) {
                    lobbyHeader
                    trainerNameField
                    createPanel
                    joinPanel

                    if isLoading {
                        ProgressView("Buscando conexión...")
                            .font(DSFont.body(13, weight: .bold))
                            .tint(DSColor.blue)
                    }

                    if !message.isEmpty {
                        DSDialogueBox(text: message, speaker: message.hasPrefix("Error") ? "AVISO" : "SISTEMA")
                            .foregroundStyle(message.hasPrefix("Error") ? DSColor.red : DSColor.ink)
                    }
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .onAppear { name = config.playerName }
    }

    private var lobbyBackground: some View {
        LinearGradient(colors: [DSColor.skyTop.opacity(0.62), DSColor.paper, DSColor.grass.opacity(0.22)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var lobbyHeader: some View {
        VStack(spacing: 5) {
            Text("SALA DE ENLACE")
                .font(DSFont.title(18))
                .foregroundStyle(DSColor.ink)
            Text("CREA O ENCUENTRA UNA PARTIDA")
                .font(DSFont.body(13, weight: .bold))
                .foregroundStyle(DSColor.red)
        }
        .padding(.top, 4)
    }

    private var trainerNameField: some View {
        DSPanel {
            DSInput(label: "NOMBRE DE ENTRENADOR", placeholder: "Tu nombre", text: $name)
        }
    }

    private var createPanel: some View {
        DSPanel {
            VStack(alignment: .leading, spacing: 12) {
                DSSectionTitle(title: "NUEVA AVENTURA", subtitle: "Crea una sala y espera a tu rival.", color: DSColor.blue)
                DSButton { createRoom() } label: {
                    Label("CREAR SALA", systemImage: "plus.circle.fill")
                }
                .disabled(cleanName.isEmpty || isLoading)
                .opacity(cleanName.isEmpty || isLoading ? 0.55 : 1)
            }
        }
    }

    private var joinPanel: some View {
        DSPanel {
            VStack(alignment: .leading, spacing: 12) {
                DSSectionTitle(title: "UNIRSE A UN AMIGO", subtitle: "Introduce el código que te compartieron.", color: DSColor.red)
                DSInput(label: "CÓDIGO DE SALA", placeholder: "ABCD", text: $joinCode, alignment: .center, fill: DSColor.yellow.opacity(0.22))
                    .textInputAutocapitalization(.characters)
#if os(iOS)
                    .textInputAutocapitalization(.characters)
#endif
                DSButton(tone: .secondary) { joinRoom() } label: {
                    HStack(spacing: 9) { Text("▶"); Text("UNIRSE") }
                }
                .disabled(cleanName.isEmpty || cleanJoinCode.isEmpty || isLoading)
                .opacity(cleanName.isEmpty || cleanJoinCode.isEmpty || isLoading ? 0.55 : 1)
            }
        }
    }

    private func createRoom() {
        config.playerName = cleanName
        sendRoomRequest(path: "/room", body: ["playerName": cleanName])
    }

    private func joinRoom() {
        config.playerName = cleanName
        sendRoomRequest(path: "/room/join", body: ["roomCode": cleanJoinCode, "playerName": cleanName])
    }

    private func sendRoomRequest(path: String, body: [String: String]) {
        guard let url = URL(string: "\(config.serverURL)\(path)") else { message = "URL del servidor inválida"; return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        isLoading = true
        message = "Conectando..."
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<RoomResponse, Error>
            if let error { result = .failure(error) }
            else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) { result = .failure(Self.responseError(from: data)) }
            else if let data, let roomResponse = try? JSONDecoder().decode(RoomResponse.self, from: data) { result = .success(roomResponse) }
            else { result = .failure(ClientError.invalidResponse) }
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let roomResponse):
                    config.roomCode = roomResponse.roomCode; config.playerId = roomResponse.playerId; config.playerSlot = roomResponse.role == "guest" ? 2 : 1
                    message = path == "/room" ? "Sala creada: \(roomResponse.roomCode)" : "Unido a sala: \(roomResponse.roomCode)"
                case .failure(let error): message = "Error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private static func responseError(from data: Data?) -> Error {
        if let data, let serverError = try? JSONDecoder().decode(ServerError.self, from: data), let message = serverError.error { return ClientError.server(message) }
        return ClientError.requestFailed
    }
}

private enum ClientError: LocalizedError {
    case invalidResponse, requestFailed, server(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Respuesta inválida del servidor"
        case .requestFailed: return "La solicitud no pudo completarse"
        case .server(let message): return message
        }
    }
}

#Preview { LobbyView(config: AppConfig()) }
