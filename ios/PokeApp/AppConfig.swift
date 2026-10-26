import Foundation

/// Session data kept between launches (same as Android's Prefs):
/// serverURL, playerName, playerId, roomCode and role ("host" plays as player1, "guest" as player2).
final class AppConfig {
    private let defaults = UserDefaults.standard

    var serverURL: String? {
        get { nonEmpty("serverURL") }
        set { defaults.set(newValue, forKey: "serverURL") }
    }

    var playerName: String {
        get { defaults.string(forKey: "playerName") ?? "" }
        set { defaults.set(newValue, forKey: "playerName") }
    }

    var playerId: String? {
        get { nonEmpty("playerId") }
        set { defaults.set(newValue, forKey: "playerId") }
    }

    var roomCode: String? {
        get { nonEmpty("roomCode") }
        set { defaults.set(newValue, forKey: "roomCode") }
    }

    var role: String? {
        get { nonEmpty("role") }
        set { defaults.set(newValue, forKey: "role") }
    }

    func clearRoom() {
        playerId = nil
        roomCode = nil
        role = nil
    }

    private func nonEmpty(_ key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
