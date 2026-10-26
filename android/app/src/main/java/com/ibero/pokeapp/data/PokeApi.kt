package com.ibero.pokeapp.data

import com.google.gson.Gson
import okhttp3.OkHttpClient
import retrofit2.HttpException
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path
import java.io.IOException
import java.util.concurrent.TimeUnit

interface PokeApi {
    @POST("room")
    suspend fun createRoom(@Body body: CreateRoomRequest): RoomResponse

    @POST("room/join")
    suspend fun joinRoom(@Body body: JoinRoomRequest): RoomResponse

    @GET("room/{code}")
    suspend fun roomState(@Path("code") code: String): RoomState

    @GET("room/{code}/pokemon")
    suspend fun pokemon(@Path("code") code: String, @Header("playerid") playerId: String): PokemonListResponse

    @POST("room/{code}/team")
    suspend fun sendTeam(@Path("code") code: String, @Body body: TeamRequest): SuccessResponse

    @POST("room/{code}/ready")
    suspend fun ready(@Path("code") code: String, @Body body: PlayerIdRequest): SuccessResponse

    @GET("room/{code}/battle")
    suspend fun battle(@Path("code") code: String): BattleState

    @POST("room/{code}/battle/move")
    suspend fun move(@Path("code") code: String, @Body body: MoveRequest): MoveResponse

    @POST("room/{code}/battle/forfeit")
    suspend fun forfeit(@Path("code") code: String, @Body body: PlayerIdRequest): ForfeitResponse

    // Health check: the server answers { status: "ok" } on "/".
    @GET(".")
    suspend fun health(): Map<String, Any?>

    companion object {
        fun create(serverUrl: String): PokeApi {
            val client = OkHttpClient.Builder()
                .connectTimeout(5, TimeUnit.SECONDS)
                // The first /pokemon call makes the server hit PokeAPI many times; it can take a while.
                .readTimeout(60, TimeUnit.SECONDS)
                .build()
            return Retrofit.Builder()
                .baseUrl(serverUrl.trimEnd('/') + "/")
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
                .create(PokeApi::class.java)
        }
    }
}

/** Turns a network/HTTP failure into a short Spanish message for the UI. */
fun Throwable.toUserMessage(): String = when (this) {
    is HttpException -> {
        val serverError = runCatching {
            Gson().fromJson(response()?.errorBody()?.string(), ErrorResponse::class.java)?.error
        }.getOrNull()
        serverError ?: "Error del servidor (${code()})"
    }
    is IOException -> "No se pudo conectar con el servidor. Revisa la IP y que estén en la misma red WiFi."
    else -> message ?: "Error inesperado"
}
