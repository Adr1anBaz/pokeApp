import Foundation
import SwiftUI

enum Screen {
    case onboarding, lobby, join, waitingRoom, teamSelect, battle, result
}

/// HP of both Pokémon when we sent our move; once either changes, the turn was resolved.
private struct TurnMarker: Equatable {
    let battleNumber: Int
    let hp1: Int
    let hp2: Int
}

/// App state, navigation and polling (port of android/.../GameViewModel.kt).
@MainActor
final class GameViewModel: ObservableObject {
    static let roomPollSeconds = 2.0
    static let battlePollSeconds = 1.0
    static let opponentArrivalSeconds = 1.8
    static let pollError = "Sin conexión con el servidor, reintentando…"

    private let config = AppConfig()
    private var api: APIClient?
    private var pollTask: Task<Void, Never>?
    private var opponentArriving = false

    @Published private(set) var screen: Screen
    @Published private(set) var serverURL: String?
    @Published private(set) var playerName: String
    @Published private(set) var roomCode: String?
    var playerId: String? { config.playerId }

    @Published private(set) var loading = false
    @Published var error: String?
    /// Set when the onboarding health check failed, so the user can still save the IP.
    @Published private(set) var connectionFailed = false

    @Published private(set) var room: RoomState?

    @Published private(set) var pokemon: [Pokemon] = []
    /// Selected Pokémon ids; position in the list is the battle order (1, 2, 3).
    @Published private(set) var selected: [Int] = []
    @Published private(set) var teamSent = false
    @Published private(set) var readySent = false

    @Published private(set) var battle: BattleState?
    @Published private var turnMarker: TurnMarker?
    var waitingForOpponent: Bool { turnMarker != nil }

    init() {
        // A local copy: `self.config` can't be read until every property is initialized.
        let saved = AppConfig()
        let url = saved.serverURL
        serverURL = url
        playerName = saved.playerName
        roomCode = saved.roomCode
        screen = url == nil ? .onboarding : .lobby
        api = url.map { APIClient(serverURL: $0) }
    }

    /// Our side in the battle response: the host is player1, the guest player2.
    var myKey: String { config.role == "guest" ? "player2" : "player1" }
    var me: PlayerInfo? { room?.players?.first { $0.playerId == config.playerId } }
    var opponent: PlayerInfo? { room?.players?.first { $0.playerId != config.playerId } }

    // MARK: - Onboarding

    func saveServer(_ input: String, name: String, skipCheck: Bool = false) {
        guard let url = Self.normalizeServerURL(input) else {
            error = "Escribe la IP del servidor"
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            error = "Escribe tu nombre"
            return
        }
        let newApi = APIClient(serverURL: url)
        launchRequest {
            if !skipCheck {
                do {
                    try await newApi.health()
                } catch {
                    self.connectionFailed = true
                    throw error
                }
            }
            self.config.serverURL = url
            self.config.playerName = trimmed
            self.api = newApi
            self.serverURL = url
            self.playerName = trimmed
            self.connectionFailed = false
            self.go(.lobby)
        }
    }

    func changeServer() {
        connectionFailed = false
        go(.onboarding)
    }

    // MARK: - Lobby / create / join

    func updateName(_ name: String) {
        playerName = name
        config.playerName = name.trimmingCharacters(in: .whitespaces)
    }

    func createRoom() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            error = "Escribe tu nombre"
            return
        }
        launchRequest {
            let res = try await self.requireApi().createRoom(playerName: name)
            self.enterRoom(res)
        }
    }

    func openJoin() { go(.join) }

    func joinRoom(_ code: String) {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        let cleanCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !name.isEmpty else {
            error = "Escribe tu nombre"
            return
        }
        guard cleanCode.count == 4 else {
            error = "El código de sala tiene 4 letras"
            return
        }
        launchRequest {
            let res = try await self.requireApi().joinRoom(code: cleanCode, playerName: name)
            self.enterRoom(res)
        }
    }

    private func enterRoom(_ res: RoomResponse) {
        config.roomCode = res.roomCode
        config.playerId = res.playerId
        config.role = res.role
        roomCode = res.roomCode
        resetMatchState()
        go(.waitingRoom)
    }

    /// Re-enter a room saved from a previous session; the room polling sends us to the right screen.
    func resumeRoom() {
        resetMatchState()
        go(.waitingRoom)
    }

    func leaveRoom() {
        // Tell the server so the rival's room is reset; it doesn't matter if this fails.
        if let api, let code = config.roomCode, let id = config.playerId {
            Task { try? await api.leave(code: code, playerId: id) }
        }
        config.clearRoom()
        roomCode = nil
        resetMatchState()
        go(.lobby)
    }

    func backToLobby() { go(.lobby) }

    private func resetMatchState() {
        room = nil
        pokemon = []
        selected = []
        teamSent = false
        readySent = false
        battle = nil
        turnMarker = nil
        opponentArriving = false
    }

    // MARK: - Team selection

    func loadPokemon() {
        guard let code = roomCode, let id = playerId, pokemon.isEmpty, !loading else { return }
        launchRequest {
            self.pokemon = try await self.requireApi().pokemon(code: code, playerId: id).pokemon ?? []
        }
    }

    func toggleSelection(_ id: Int) {
        guard !readySent else { return }
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else if selected.count < 3 {
            selected.append(id)
        }
        // Changing the team after confirming means it has to be sent again.
        teamSent = false
    }

    func confirmTeam() {
        guard let code = roomCode, let id = playerId else { return }
        guard selected.count == 3 else {
            error = "Elige exactamente 3 Pokémon"
            return
        }
        let team = selected
        launchRequest {
            try await self.requireApi().sendTeam(code: code, playerId: id, team: team)
            self.teamSent = true
        }
    }

    func markReady() {
        guard let code = roomCode, let id = playerId else { return }
        launchRequest {
            try await self.requireApi().ready(code: code, playerId: id)
            self.readySent = true
        }
    }

    /// The Pokémon this player picked, in battle order (empty after resuming a room).
    var myTeam: [Pokemon] { selected.compactMap { id in pokemon.first { $0.id == id } } }

    // MARK: - Battle

    func myPokemon(_ b: BattleState?) -> BattlePokemon? {
        myKey == "player1" ? b?.currentPokemon?.player1 : b?.currentPokemon?.player2
    }

    func opponentPokemon(_ b: BattleState?) -> BattlePokemon? {
        myKey == "player1" ? b?.currentPokemon?.player2 : b?.currentPokemon?.player1
    }

    func myScore(_ b: BattleState?) -> Int {
        guard let s = b?.score else { return 0 }
        return myKey == "player1" ? s.player1 : s.player2
    }

    func opponentScore(_ b: BattleState?) -> Int {
        guard let s = b?.score else { return 0 }
        return myKey == "player1" ? s.player2 : s.player1
    }

    /// Whether this player won, using the forfeit when there was one (the score may still be tied).
    func iWon(_ b: BattleState?) -> Bool {
        if let side = b?.forfeitedBy { return side != myKey }
        return myScore(b) > opponentScore(b)
    }

    func sendMove(_ moveId: Int) {
        guard let code = roomCode, let id = playerId, let b = battle, !waitingForOpponent else { return }
        let marker = TurnMarker(
            battleNumber: b.battleNumber,
            hp1: b.currentPokemon?.player1?.hp ?? 0,
            hp2: b.currentPokemon?.player2?.hp ?? 0
        )
        launchRequest {
            self.turnMarker = marker
            do {
                let res = try await self.requireApi().move(code: code, playerId: id, moveId: moveId)
                // Both moves were in: the turn is already resolved, refresh right away.
                if !res.waitingForOpponent {
                    self.turnMarker = nil
                    try await self.refreshBattle()
                }
            } catch {
                self.turnMarker = nil
                throw error
            }
        }
    }

    /// Give up the match: the rival wins. The next battle refresh brings the winner.
    func forfeit() {
        guard let code = roomCode, let id = playerId else { return }
        launchRequest {
            try await self.requireApi().forfeit(code: code, playerId: id)
            self.turnMarker = nil
            try await self.refreshBattle()
        }
    }

    func showResult() { go(.result) }

    // MARK: - Navigation & polling

    private func go(_ target: Screen) {
        error = nil
        withAnimation(.easeInOut(duration: 0.3)) { screen = target }
        pollTask?.cancel()
        switch target {
        case .waitingRoom, .teamSelect:
            pollTask = poll(every: Self.roomPollSeconds) { try await $0.refreshRoom() }
        case .battle:
            pollTask = poll(every: Self.battlePollSeconds) { try await $0.refreshBattle() }
        default:
            pollTask = nil
        }
    }

    private func poll(every seconds: Double, _ block: @escaping @MainActor (GameViewModel) async throws -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await block(self)
                    if Task.isCancelled { return }
                    if self.error == Self.pollError { self.error = nil }
                } catch {
                    if Task.isCancelled { return }
                    if let apiError = error as? APIError, apiError.isNotFound, self.screen != .battle {
                        // Server restarted or the room is gone: nothing left to poll.
                        self.config.clearRoom()
                        self.roomCode = nil
                        self.resetMatchState()
                        self.go(.lobby)
                        self.error = "La sala ya no existe en el servidor"
                        return
                    }
                    self.error = Self.pollError
                }
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    private func refreshRoom() async throws {
        guard let code = roomCode else { return }
        let state = try await requireApi().roomState(code: code)
        room = state
        // Restore progress after resuming a room.
        if let me {
            if me.ready { readySent = true }
            if me.hasTeam && !teamSent && selected.isEmpty { teamSent = true }
        }
        if state.status == "battle" || state.status == "finished" {
            go(.battle)
        } else if screen == .waitingRoom && (state.players?.count ?? 0) >= 2 && !opponentArriving {
            // Let the "rival found" moment play before moving on.
            opponentArriving = true
            Task {
                try? await Task.sleep(nanoseconds: UInt64(Self.opponentArrivalSeconds * 1_000_000_000))
                self.opponentArriving = false
                if self.screen == .waitingRoom { self.go(.teamSelect) }
            }
        }
    }

    private func refreshBattle() async throws {
        guard let code = roomCode else { return }
        let b = try await requireApi().battle(code: code)
        battle = b
        if let m = turnMarker {
            let hp1 = b.currentPokemon?.player1?.hp
            let hp2 = b.currentPokemon?.player2?.hp
            // Damage is always at least 1, so a resolved turn always changes an HP.
            if b.battleNumber != m.battleNumber || hp1 != m.hp1 || hp2 != m.hp2 || b.winner != nil {
                turnMarker = nil
            }
        }
        if let cp = b.currentPokemon {
            MoveNames.shared.prefetch((cp.player1?.moves ?? []) + (cp.player2?.moves ?? []))
        }
        // The match is decided: stop polling. The battle screen calls showResult()
        // once the final knockout has been animated.
        if b.winner != nil { pollTask?.cancel() }
    }

    private func launchRequest(_ block: @escaping @MainActor () async throws -> Void) {
        guard !loading else { return }
        Task {
            loading = true
            error = nil
            do {
                try await block()
            } catch is CancellationError {
            } catch {
                self.error = userMessage(for: error)
            }
            loading = false
        }
    }

    private func requireApi() throws -> APIClient {
        guard let api else { throw APIError.http(0, "Configura primero la IP del servidor") }
        return api
    }

    /// "172.22.41.221" -> "http://172.22.41.221:3000"; full URLs and ip:port are kept as typed.
    static func normalizeServerURL(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("/") { text.removeLast() }
        if text.isEmpty { return nil }
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return text }
        if text.contains(":") { return "http://\(text)" }
        return "http://\(text):3000"
    }
}
