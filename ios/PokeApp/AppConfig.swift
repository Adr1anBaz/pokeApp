import Foundation
import Combine

final class AppConfig: ObservableObject {
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
        }
    }

    @Published var playerId: String {
        didSet {
            UserDefaults.standard.set(playerId, forKey: "playerId")
        }
    }

    @Published var roomCode: String {
        didSet {
            UserDefaults.standard.set(roomCode, forKey: "roomCode")
        }
    }

    @Published var playerName: String {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "playerName")
        }
    }

    @Published var playerSlot: Int {
        didSet {
            UserDefaults.standard.set(playerSlot, forKey: "playerSlot")
        }
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        playerId = UserDefaults.standard.string(forKey: "playerId") ?? ""
        roomCode = UserDefaults.standard.string(forKey: "roomCode") ?? ""
        playerName = UserDefaults.standard.string(forKey: "playerName") ?? "Jugador"
        playerSlot = UserDefaults.standard.integer(forKey: "playerSlot")
        if playerSlot == 0 {
            playerSlot = 1
        }
    }

    var hasServer: Bool {
        !serverURL.isEmpty
    }

    func clearRoom() {
        roomCode = ""
        playerId = ""
        playerSlot = 1
    }
}
