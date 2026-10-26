package com.ibero.pokeapp.data

import android.content.Context
import androidx.core.content.edit

/** Session data the instructions ask to keep locally: serverUrl, playerName, playerId, roomCode (+ role). */
class Prefs(context: Context) {
    private val prefs = context.getSharedPreferences("pokeapp_prefs", Context.MODE_PRIVATE)

    var serverUrl: String?
        get() = prefs.getString(KEY_SERVER_URL, null)
        set(value) = prefs.edit { putString(KEY_SERVER_URL, value) }

    var playerName: String
        get() = prefs.getString(KEY_PLAYER_NAME, "") ?: ""
        set(value) = prefs.edit { putString(KEY_PLAYER_NAME, value) }

    var playerId: String?
        get() = prefs.getString(KEY_PLAYER_ID, null)
        set(value) = prefs.edit { putString(KEY_PLAYER_ID, value) }

    var roomCode: String?
        get() = prefs.getString(KEY_ROOM_CODE, null)
        set(value) = prefs.edit { putString(KEY_ROOM_CODE, value) }

    /** "host" plays as player1 in the battle, "guest" as player2. */
    var role: String?
        get() = prefs.getString(KEY_ROLE, null)
        set(value) = prefs.edit { putString(KEY_ROLE, value) }

    fun clearRoom() {
        playerId = null
        roomCode = null
        role = null
    }

    private companion object {
        const val KEY_SERVER_URL = "serverUrl"
        const val KEY_PLAYER_NAME = "playerName"
        const val KEY_PLAYER_ID = "playerId"
        const val KEY_ROOM_CODE = "roomCode"
        const val KEY_ROLE = "role"
    }
}
