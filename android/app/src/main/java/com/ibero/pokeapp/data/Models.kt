package com.ibero.pokeapp.data

// Request/response bodies from contratoApp.md. Gson ignores Kotlin nullability,
// so anything the server might omit is declared nullable.

data class CreateRoomRequest(val playerName: String)

data class JoinRoomRequest(val roomCode: String, val playerName: String)

data class RoomResponse(
    val roomCode: String,
    val playerId: String,
    val role: String,
    val hostName: String?,
)

data class RoomState(
    val roomCode: String,
    val status: String,
    val players: List<PlayerInfo>?,
)

data class PlayerInfo(
    val playerId: String,
    val name: String,
    val ready: Boolean,
    val hasTeam: Boolean,
)

data class PokemonListResponse(val pokemon: List<Pokemon>?)

data class Pokemon(
    val id: Int,
    val name: String,
    val sprite: String?,
    val types: List<String>?,
    val stats: Map<String, Int>?,
)

data class TeamEntry(val pokemonId: Int, val order: Int)

data class TeamRequest(val playerId: String, val team: List<TeamEntry>)

data class PlayerIdRequest(val playerId: String)

data class SuccessResponse(val success: Boolean)

data class BattleState(
    val battleNumber: Int,
    val status: String,
    val currentPokemon: CurrentPokemon?,
    val score: Score?,
    val winner: String?,
    val lastTurn: LastTurn?,
)

data class CurrentPokemon(val player1: BattlePokemon?, val player2: BattlePokemon?)

data class BattlePokemon(
    val pokemonId: Int,
    val name: String,
    val hp: Int,
    val maxHp: Int,
    val moves: List<Move>?,
)

data class Move(
    val id: Int,
    val name: String,
    val power: Int?,
    val accuracy: Int?,
    val type: String?,
    val damageClass: String?,
)

data class Score(val player1: Int, val player2: Int)

data class LastTurn(
    val player1Move: String?,
    val player2Move: String?,
    val damageToPlayer1: Int?,
    val damageToPlayer2: Int?,
    val logs: List<String>?,
)

data class MoveRequest(val playerId: String, val moveId: Int)

data class MoveResponse(val accepted: Boolean, val waitingForOpponent: Boolean)

data class ErrorResponse(val error: String?)
