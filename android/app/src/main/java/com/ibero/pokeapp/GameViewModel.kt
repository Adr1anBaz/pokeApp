package com.ibero.pokeapp

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.ibero.pokeapp.data.BattlePokemon
import com.ibero.pokeapp.data.BattleState
import com.ibero.pokeapp.data.CreateRoomRequest
import com.ibero.pokeapp.data.JoinRoomRequest
import com.ibero.pokeapp.data.MoveRequest
import com.ibero.pokeapp.data.PlayerIdRequest
import com.ibero.pokeapp.data.PlayerInfo
import com.ibero.pokeapp.data.PokeApi
import com.ibero.pokeapp.data.Pokemon
import com.ibero.pokeapp.data.Prefs
import com.ibero.pokeapp.data.RoomResponse
import com.ibero.pokeapp.data.RoomState
import com.ibero.pokeapp.data.TeamEntry
import com.ibero.pokeapp.data.TeamRequest
import com.ibero.pokeapp.data.toUserMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import retrofit2.HttpException

enum class Screen { Onboarding, Lobby, Join, WaitingRoom, TeamSelect, Battle, Result }

/** HP of both Pokémon when we sent our move; once either changes, the turn was resolved. */
private data class TurnMarker(val battleNumber: Int, val hp1: Int, val hp2: Int)

class GameViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = Prefs(app)
    private var api: PokeApi? = prefs.serverUrl?.let { PokeApi.create(it) }
    private var pollJob: Job? = null

    var screen by mutableStateOf(if (prefs.serverUrl == null) Screen.Onboarding else Screen.Lobby)
        private set
    var serverUrl by mutableStateOf(prefs.serverUrl)
        private set
    var playerName by mutableStateOf(prefs.playerName)
        private set
    var roomCode by mutableStateOf(prefs.roomCode)
        private set
    val playerId: String? get() = prefs.playerId

    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set
    /** Set when the onboarding health check failed, so the user can still save the IP. */
    var connectionFailed by mutableStateOf(false)
        private set

    var room by mutableStateOf<RoomState?>(null)
        private set

    var pokemon by mutableStateOf<List<Pokemon>>(emptyList())
        private set
    /** Selected Pokémon ids; position in the list is the battle order (1, 2, 3). */
    val selected = mutableStateListOf<Int>()
    var teamSent by mutableStateOf(false)
        private set
    var readySent by mutableStateOf(false)
        private set

    var battle by mutableStateOf<BattleState?>(null)
        private set
    private var turnMarker by mutableStateOf<TurnMarker?>(null)
    val waitingForOpponent: Boolean get() = turnMarker != null

    /** Our side in the battle response: the host is player1, the guest player2. */
    val myKey: String get() = if (prefs.role == "guest") "player2" else "player1"
    val me: PlayerInfo? get() = room?.players?.find { it.playerId == prefs.playerId }
    val opponent: PlayerInfo? get() = room?.players?.find { it.playerId != prefs.playerId }

    fun clearError() {
        error = null
    }

    // ---------- Onboarding ----------

    fun saveServer(input: String, name: String, skipCheck: Boolean = false) {
        val url = normalizeServerUrl(input)
        if (url == null) {
            error = "Escribe la IP del servidor"
            return
        }
        if (name.isBlank()) {
            error = "Escribe tu nombre"
            return
        }
        val newApi = PokeApi.create(url)
        launchRequest {
            if (!skipCheck) {
                try {
                    newApi.health()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    connectionFailed = true
                    throw e
                }
            }
            prefs.serverUrl = url
            prefs.playerName = name.trim()
            api = newApi
            serverUrl = url
            playerName = name.trim()
            connectionFailed = false
            go(Screen.Lobby)
        }
    }

    fun changeServer() {
        connectionFailed = false
        go(Screen.Onboarding)
    }

    // ---------- Lobby / create / join ----------

    fun updateName(name: String) {
        playerName = name
        prefs.playerName = name.trim()
    }

    fun createRoom() {
        val name = playerName.trim()
        if (name.isEmpty()) {
            error = "Escribe tu nombre"
            return
        }
        launchRequest { enterRoom(requireApi().createRoom(CreateRoomRequest(name))) }
    }

    fun openJoin() = go(Screen.Join)

    fun joinRoom(code: String) {
        val name = playerName.trim()
        val cleanCode = code.trim().uppercase()
        if (name.isEmpty()) {
            error = "Escribe tu nombre"
            return
        }
        if (cleanCode.length != 4) {
            error = "El código de sala tiene 4 letras"
            return
        }
        launchRequest { enterRoom(requireApi().joinRoom(JoinRoomRequest(cleanCode, name))) }
    }

    private fun enterRoom(res: RoomResponse) {
        prefs.roomCode = res.roomCode
        prefs.playerId = res.playerId
        prefs.role = res.role
        roomCode = res.roomCode
        resetMatchState()
        go(Screen.WaitingRoom)
    }

    /** Re-enter a room saved from a previous session; the room polling sends us to the right screen. */
    fun resumeRoom() {
        resetMatchState()
        go(Screen.WaitingRoom)
    }

    fun leaveRoom() {
        prefs.clearRoom()
        roomCode = null
        resetMatchState()
        go(Screen.Lobby)
    }

    fun backToLobby() = go(Screen.Lobby)

    private fun resetMatchState() {
        room = null
        pokemon = emptyList()
        selected.clear()
        teamSent = false
        readySent = false
        battle = null
        turnMarker = null
    }

    // ---------- Team selection ----------

    fun loadPokemon() {
        val code = roomCode ?: return
        val id = playerId ?: return
        if (pokemon.isNotEmpty() || loading) return
        launchRequest { pokemon = requireApi().pokemon(code, id).pokemon.orEmpty() }
    }

    fun toggleSelection(id: Int) {
        if (readySent) return
        if (id in selected) selected.remove(id) else if (selected.size < 3) selected.add(id)
        // Changing the team after confirming means it has to be sent again.
        teamSent = false
    }

    fun confirmTeam() {
        val code = roomCode ?: return
        val id = playerId ?: return
        if (selected.size != 3) {
            error = "Elige exactamente 3 Pokémon"
            return
        }
        val team = selected.mapIndexed { index, pokemonId -> TeamEntry(pokemonId, index + 1) }
        launchRequest {
            requireApi().sendTeam(code, TeamRequest(id, team))
            teamSent = true
        }
    }

    fun markReady() {
        val code = roomCode ?: return
        val id = playerId ?: return
        launchRequest {
            requireApi().ready(code, PlayerIdRequest(id))
            readySent = true
        }
    }

    // ---------- Battle ----------

    fun myPokemon(b: BattleState?): BattlePokemon? =
        b?.currentPokemon?.let { if (myKey == "player1") it.player1 else it.player2 }

    fun opponentPokemon(b: BattleState?): BattlePokemon? =
        b?.currentPokemon?.let { if (myKey == "player1") it.player2 else it.player1 }

    fun myScore(b: BattleState?): Int = b?.score?.let { if (myKey == "player1") it.player1 else it.player2 } ?: 0
    fun opponentScore(b: BattleState?): Int = b?.score?.let { if (myKey == "player1") it.player2 else it.player1 } ?: 0

    fun sendMove(moveId: Int) {
        val code = roomCode ?: return
        val id = playerId ?: return
        val b = battle ?: return
        if (waitingForOpponent) return
        val p1 = b.currentPokemon?.player1
        val p2 = b.currentPokemon?.player2
        launchRequest {
            turnMarker = TurnMarker(b.battleNumber, p1?.hp ?: 0, p2?.hp ?: 0)
            try {
                val res = requireApi().move(code, MoveRequest(id, moveId))
                // Both moves were in: the turn is already resolved, refresh right away.
                if (!res.waitingForOpponent) {
                    turnMarker = null
                    refreshBattle()
                }
            } catch (e: Exception) {
                turnMarker = null
                throw e
            }
        }
    }

    // ---------- Navigation & polling ----------

    private fun go(target: Screen) {
        error = null
        screen = target
        pollJob?.cancel()
        pollJob = when (target) {
            Screen.WaitingRoom, Screen.TeamSelect -> poll(ROOM_POLL_MS) { refreshRoom() }
            Screen.Battle -> poll(BATTLE_POLL_MS) { refreshBattle() }
            else -> null
        }
    }

    private fun poll(intervalMs: Long, block: suspend () -> Unit): Job = viewModelScope.launch {
        while (isActive) {
            try {
                block()
                if (error == POLL_ERROR) error = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: HttpException) {
                if (e.code() == 404 && screen != Screen.Battle) {
                    // Server restarted or the room is gone: nothing left to poll.
                    prefs.clearRoom()
                    roomCode = null
                    resetMatchState()
                    go(Screen.Lobby)
                    error = "La sala ya no existe en el servidor"
                    return@launch
                }
                error = POLL_ERROR
            } catch (e: Exception) {
                error = POLL_ERROR
            }
            delay(intervalMs)
        }
    }

    private suspend fun refreshRoom() {
        val code = roomCode ?: return
        val state = requireApi().roomState(code)
        room = state
        // Restore progress after resuming a room.
        me?.let {
            if (it.ready) readySent = true
            if (it.hasTeam && !teamSent && selected.isEmpty()) teamSent = true
        }
        when {
            state.status == "battle" || state.status == "finished" -> go(Screen.Battle)
            screen == Screen.WaitingRoom && state.players.orEmpty().size >= 2 -> go(Screen.TeamSelect)
        }
    }

    private suspend fun refreshBattle() {
        val code = roomCode ?: return
        val b = requireApi().battle(code)
        battle = b
        turnMarker?.let { m ->
            val p1 = b.currentPokemon?.player1?.hp
            val p2 = b.currentPokemon?.player2?.hp
            // Damage is always at least 1, so a resolved turn always changes an HP.
            if (b.battleNumber != m.battleNumber || p1 != m.hp1 || p2 != m.hp2 || b.winner != null) {
                turnMarker = null
            }
        }
        if (b.winner != null) go(Screen.Result)
    }

    private fun launchRequest(block: suspend () -> Unit) {
        if (loading) return
        viewModelScope.launch {
            loading = true
            error = null
            try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = e.toUserMessage()
            } finally {
                loading = false
            }
        }
    }

    private fun requireApi(): PokeApi = api ?: throw IllegalStateException("Configura primero la IP del servidor")

    companion object {
        const val ROOM_POLL_MS = 2000L
        const val BATTLE_POLL_MS = 1500L
        const val POLL_ERROR = "Sin conexión con el servidor, reintentando…"

        /** "172.22.41.221" -> "http://172.22.41.221:3000"; full URLs and ip:port are kept as typed. */
        fun normalizeServerUrl(input: String): String? {
            val text = input.trim().trimEnd('/')
            if (text.isEmpty()) return null
            return when {
                text.startsWith("http://") || text.startsWith("https://") -> text
                ':' in text -> "http://$text"
                else -> "http://$text:3000"
            }
        }
    }
}
