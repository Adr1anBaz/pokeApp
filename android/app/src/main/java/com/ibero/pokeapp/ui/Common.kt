package com.ibero.pokeapp.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage

/** Scrollable, padded column used by every screen. */
@Composable
fun ScreenColumn(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Composable
fun ErrorText(message: String?) {
    if (message == null) return
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Text(
            message,
            modifier = Modifier.padding(12.dp),
            color = MaterialTheme.colorScheme.onErrorContainer,
        )
    }
}

@Composable
fun PokemonSprite(url: String?, size: Dp = 72.dp) {
    if (url == null) return
    AsyncImage(model = url, contentDescription = null, modifier = Modifier.size(size))
}

fun spriteUrl(pokemonId: Int) =
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pokemonId.png"

fun String.displayName() = replace('-', ' ').replaceFirstChar { it.uppercase() }

fun statusLabel(status: String?) = when (status) {
    "waiting" -> "Esperando al otro jugador"
    "selecting" -> "Eligiendo equipos"
    "ready" -> "Esperando que ambos estén listos"
    "battle" -> "En batalla"
    "finished" -> "Terminada"
    null -> "Cargando…"
    else -> status
}
