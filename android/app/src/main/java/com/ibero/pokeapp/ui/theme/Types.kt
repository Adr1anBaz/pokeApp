package com.ibero.pokeapp.ui.theme

import androidx.compose.ui.graphics.Color

/** Visual info per Pokémon type: card/badge color and Spanish name. */
data class TypeStyle(val color: Color, val dark: Color, val es: String)

object PokeTypes {
    private val styles = mapOf(
        "normal" to TypeStyle(Color(0xFFA8A878), Color(0xFF6D6D4E), "Normal"),
        "fire" to TypeStyle(Color(0xFFF08030), Color(0xFF9C531F), "Fuego"),
        "water" to TypeStyle(Color(0xFF6890F0), Color(0xFF445E9C), "Agua"),
        "electric" to TypeStyle(Color(0xFFF8D030), Color(0xFFA1871F), "Eléctrico"),
        "grass" to TypeStyle(Color(0xFF78C850), Color(0xFF4E8234), "Planta"),
        "ice" to TypeStyle(Color(0xFF98D8D8), Color(0xFF638D8D), "Hielo"),
        "fighting" to TypeStyle(Color(0xFFC03028), Color(0xFF7D1F1A), "Lucha"),
        "poison" to TypeStyle(Color(0xFFA040A0), Color(0xFF682A68), "Veneno"),
        "ground" to TypeStyle(Color(0xFFE0C068), Color(0xFF927D44), "Tierra"),
        "flying" to TypeStyle(Color(0xFFA890F0), Color(0xFF6D5E9C), "Volador"),
        "psychic" to TypeStyle(Color(0xFFF85888), Color(0xFFA13959), "Psíquico"),
        "bug" to TypeStyle(Color(0xFFA8B820), Color(0xFF6D7815), "Bicho"),
        "rock" to TypeStyle(Color(0xFFB8A038), Color(0xFF786824), "Roca"),
        "ghost" to TypeStyle(Color(0xFF705898), Color(0xFF493963), "Fantasma"),
        "dragon" to TypeStyle(Color(0xFF7038F8), Color(0xFF4924A1), "Dragón"),
        "dark" to TypeStyle(Color(0xFF705848), Color(0xFF49392F), "Siniestro"),
        "steel" to TypeStyle(Color(0xFFB8B8D0), Color(0xFF787887), "Acero"),
        "fairy" to TypeStyle(Color(0xFFEE99AC), Color(0xFF9B6470), "Hada"),
    )

    fun style(type: String?): TypeStyle = styles[type] ?: styles.getValue("normal")

    /**
     * Mirrors calculateDamage() in pokemon-server/server.js (its small chart, defender's first type),
     * so the "super effective" text matches the damage the server really applied.
     * Used only when the server doesn't send an effectiveness value itself.
     */
    private val serverChart = mapOf(
        "fire" to mapOf("grass" to 2.0, "water" to 0.5, "fire" to 0.5),
        "water" to mapOf("fire" to 2.0, "grass" to 0.5, "water" to 0.5),
        "grass" to mapOf("water" to 2.0, "fire" to 0.5, "grass" to 0.5),
        "electric" to mapOf("water" to 2.0, "grass" to 0.5, "electric" to 0.5),
    )

    fun serverEffectiveness(moveType: String?, defenderTypes: List<String>?): Double =
        serverChart[moveType]?.get(defenderTypes?.firstOrNull()) ?: 1.0
}

/** Sprite URLs served by PokeAPI's sprites repo (nothing is downloaded into the project). */
object Sprites {
    private const val BASE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    fun animatedFront(id: Int) = "$BASE/other/showdown/$id.gif"
    fun animatedBack(id: Int) = "$BASE/other/showdown/back/$id.gif"
    fun front(id: Int) = "$BASE/$id.png"
    fun back(id: Int) = "$BASE/back/$id.png"
    fun artwork(id: Int) = "$BASE/other/official-artwork/$id.png"
    fun cry(id: Int) = "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/$id.ogg"

    private val typeIds = listOf(
        "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
        "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy",
    )

    /** Official Scarlet/Violet type symbol (no text), 60x60. */
    fun typeIcon(type: String?): String {
        val id = typeIds.indexOf(type).takeIf { it >= 0 }?.plus(1) ?: 1
        return "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/types/generation-ix/scarlet-violet/small/$id.png"
    }
}
