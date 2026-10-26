package com.ibero.pokeapp.data

import android.content.Context
import androidx.compose.runtime.mutableStateMapOf
import androidx.core.content.edit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.URL

/**
 * Spanish move names from PokeAPI (/move/{id}), Latin-American first.
 * Cached in memory and in SharedPreferences so each move is fetched only once.
 */
object MoveNames {
    private val names = mutableStateMapOf<Int, String>()
    private val requested = mutableSetOf<Int>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun name(move: Move): String = names[move.id] ?: move.name.prettyName()

    fun prefetch(context: Context, moves: List<Move>) {
        val prefs = context.getSharedPreferences("move_names", Context.MODE_PRIVATE)
        moves.forEach { move ->
            if (move.id in names || !requested.add(move.id)) return@forEach
            prefs.getString(move.id.toString(), null)?.let {
                names[move.id] = it
                return@forEach
            }
            scope.launch {
                runCatching {
                    val json = JSONObject(URL("https://pokeapi.co/api/v2/move/${move.id}").readText())
                    val list = json.getJSONArray("names")
                    val byLang = (0 until list.length()).associate {
                        val n = list.getJSONObject(it)
                        n.getJSONObject("language").getString("name") to n.getString("name")
                    }
                    (byLang["es-419"] ?: byLang["es"])?.let {
                        names[move.id] = it
                        prefs.edit { putString(move.id.toString(), it) }
                    }
                }.onFailure { requested.remove(move.id) }
            }
        }
    }
}

fun String.prettyName() = split('-').joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
