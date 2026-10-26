import Foundation

// Request/response bodies from contratoApp.md. Anything the server might omit is optional.

struct RoomResponse: Decodable {
    let roomCode: String
    let playerId: String
    let role: String
    let hostName: String?
}

struct RoomState: Decodable, Equatable {
    let roomCode: String
    let status: String
    let players: [PlayerInfo]?
}

struct PlayerInfo: Decodable, Equatable {
    let playerId: String
    let name: String
    let ready: Bool
    let hasTeam: Bool
}

struct PokemonListResponse: Decodable {
    let pokemon: [Pokemon]?
}

struct Pokemon: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let sprite: String?
    let types: [String]?
    let stats: [String: Int]?
}

struct BattleState: Decodable, Equatable {
    let battleNumber: Int
    let status: String
    let currentPokemon: CurrentPokemon?
    let score: Score?
    let winner: String?
    /// "player1" / "player2" when the match ended because that player forfeited.
    let forfeitedBy: String?
    let lastTurn: LastTurn?
}

struct CurrentPokemon: Decodable, Equatable {
    let player1: BattlePokemon?
    let player2: BattlePokemon?
}

struct BattlePokemon: Decodable, Equatable {
    let pokemonId: Int
    let name: String
    let hp: Int
    let maxHp: Int
    let moves: [Move]?
    // Not in the contract, but the server sends them; used for turn order and effectiveness.
    let stats: [String: Int]?
    let types: [String]?
}

struct Move: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let power: Int?
    let accuracy: Int?
    let type: String?
    let damageClass: String?
}

struct Score: Decodable, Equatable {
    let player1: Int
    let player2: Int
}

struct LastTurn: Decodable, Equatable {
    let player1Move: String?
    let player2Move: String?
    let damageToPlayer1: Int?
    let damageToPlayer2: Int?
    let logs: [String]?
    // Optional fields proposed for the server (see android/backend-requests.md).
    // When present the battle animations use them; otherwise the app falls back to its own guesses.
    let turnNumber: Int?
    let battleNumber: Int?
    let firstAttacker: String?
    let player1Missed: Bool?
    let player2Missed: Bool?
    let player1Effectiveness: Double?
    let player2Effectiveness: Double?
}

struct MoveResponse: Decodable {
    let accepted: Bool
    let waitingForOpponent: Bool
}

private struct ErrorResponse: Decodable {
    let error: String?
}

private struct Ignored: Decodable {}

enum APIError: Error {
    case http(Int, String?)
    case network
    case decoding

    /// Short Spanish message for the UI.
    var userMessage: String {
        switch self {
        case .http(let code, let serverError): return serverError ?? "Error del servidor (\(code))"
        case .network: return "No se pudo conectar con el servidor. Revisa la IP y que estén en la misma red WiFi."
        case .decoding: return "Respuesta inesperada del servidor"
        }
    }

    var isNotFound: Bool {
        if case .http(404, _) = self { return true }
        return false
    }
}

func userMessage(for error: Error) -> String {
    (error as? APIError)?.userMessage ?? error.localizedDescription
}

/// Endpoints of pokemon-server.
struct APIClient {
    private let base: String
    private let session: URLSession

    init(serverURL: String) {
        base = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        let config = URLSessionConfiguration.default
        // The first /pokemon call makes the server hit PokeAPI many times; it can take a while.
        config.timeoutIntervalForRequest = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func health() async throws {
        let _: Ignored = try await request("GET", "/", timeout: 5)
    }

    func createRoom(playerName: String) async throws -> RoomResponse {
        try await request("POST", "/room", body: ["playerName": playerName])
    }

    func joinRoom(code: String, playerName: String) async throws -> RoomResponse {
        try await request("POST", "/room/join", body: ["roomCode": code, "playerName": playerName])
    }

    func roomState(code: String) async throws -> RoomState {
        try await request("GET", "/room/\(code)", timeout: 10)
    }

    func pokemon(code: String, playerId: String) async throws -> PokemonListResponse {
        try await request("GET", "/room/\(code)/pokemon", headers: ["playerid": playerId])
    }

    func sendTeam(code: String, playerId: String, team: [Int]) async throws {
        let entries = team.enumerated().map { ["pokemonId": $0.element, "order": $0.offset + 1] }
        let _: Ignored = try await request("POST", "/room/\(code)/team", body: ["playerId": playerId, "team": entries])
    }

    func ready(code: String, playerId: String) async throws {
        let _: Ignored = try await request("POST", "/room/\(code)/ready", body: ["playerId": playerId])
    }

    func battle(code: String) async throws -> BattleState {
        try await request("GET", "/room/\(code)/battle", timeout: 10)
    }

    func move(code: String, playerId: String, moveId: Int) async throws -> MoveResponse {
        try await request("POST", "/room/\(code)/battle/move", body: ["playerId": playerId, "moveId": moveId])
    }

    func forfeit(code: String, playerId: String) async throws {
        let _: Ignored = try await request("POST", "/room/\(code)/battle/forfeit", body: ["playerId": playerId])
    }

    func leave(code: String, playerId: String) async throws {
        let _: Ignored = try await request("POST", "/room/\(code)/leave", body: ["playerId": playerId], timeout: 5)
    }

    private func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval = 60
    ) async throws -> T {
        guard let url = URL(string: base + path) else { throw APIError.network }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        guard (200...299).contains(http.statusCode) else {
            let serverError = try? JSONDecoder().decode(ErrorResponse.self, from: data).error
            throw APIError.http(http.statusCode, serverError)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

extension String {
    /// "mr-mime" -> "Mr Mime"
    var prettyName: String {
        split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
