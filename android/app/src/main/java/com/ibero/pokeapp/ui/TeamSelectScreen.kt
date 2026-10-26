package com.ibero.pokeapp.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.data.Pokemon
import com.ibero.pokeapp.data.prettyName
import com.ibero.pokeapp.ui.components.DsPanel
import com.ibero.pokeapp.ui.components.ErrorBanner
import com.ibero.pokeapp.ui.components.PixelButton
import com.ibero.pokeapp.ui.components.PixelSprite
import com.ibero.pokeapp.ui.components.Pokeball
import com.ibero.pokeapp.ui.components.SpinningPokeball
import com.ibero.pokeapp.ui.components.StripedBackground
import com.ibero.pokeapp.ui.components.TypeBadge
import com.ibero.pokeapp.ui.theme.Ds
import com.ibero.pokeapp.ui.theme.PokeTypes
import com.ibero.pokeapp.ui.theme.Sprites

@Composable
fun TeamSelectScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    LaunchedEffect(Unit) { vm.loadPokemon() }

    StripedBackground(modifier, top = Color(0xFF305878), bottom = Color(0xFF58A0C8)) {
        Column(Modifier.fillMaxSize()) {
            // Header
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Ds.Ink.copy(alpha = 0.85f))
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("ELIGE TU EQUIPO", style = MaterialTheme.typography.headlineSmall, color = Ds.Yellow)
                    Text(
                        "Sala ${vm.roomCode} · Toca 3 cartas en orden de batalla",
                        style = MaterialTheme.typography.bodySmall, color = Color.White,
                    )
                }
                val rival = vm.opponent
                Text(
                    when {
                        rival == null -> "…"
                        rival.ready -> "${rival.name}: ¡LISTO!"
                        rival.hasTeam -> "${rival.name}: equipo OK"
                        else -> "${rival.name}: eligiendo"
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (rival?.ready == true) Ds.Green else Ds.Blue)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
            ErrorBanner(vm.error, Modifier.padding(horizontal = 12.dp, vertical = 6.dp))

            Box(Modifier.weight(1f)) {
                if (vm.pokemon.isEmpty()) {
                    Column(
                        Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        if (vm.loading) {
                            SpinningPokeball(64.dp)
                            Text("Abriendo sobres…", style = MaterialTheme.typography.headlineSmall, color = Color.White)
                            Text("(puede tardar unos segundos)", style = MaterialTheme.typography.bodyMedium, color = Color.White)
                        } else {
                            PixelButton("REINTENTAR", onClick = vm::loadPokemon)
                        }
                    }
                } else {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        contentPadding = PaddingValues(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        itemsIndexed(vm.pokemon, key = { _, p -> p.id }) { index, p ->
                            val order = vm.selected.indexOf(p.id).takeIf { it >= 0 }?.plus(1)
                            TradingCard(p, order, index, enabled = !vm.readySent) {
                                if (p.id !in vm.selected && vm.selected.size < 3) Sound.cry(p.id)
                                vm.toggleSelection(p.id)
                            }
                        }
                    }
                }
            }

            PartyTray(vm)
        }
    }
}

@Composable
private fun TradingCard(p: Pokemon, order: Int?, index: Int, enabled: Boolean, onClick: () -> Unit) {
    val type = PokeTypes.style(p.types?.firstOrNull())
    // Cards are dealt in one after another.
    val deal = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(70L * index)
        deal.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMediumLow))
    }
    val lift by animateFloatAsState(if (order != null) 1f else 0f, tween(200), label = "lift")
    val stats = p.stats.orEmpty()

    Box(
        Modifier
            .graphicsLayer {
                alpha = deal.value.coerceIn(0f, 1f)
                scaleX = 0.6f + 0.4f * deal.value + 0.04f * lift
                scaleY = scaleX
                translationY = (1 - deal.value) * 120f - lift * 14f
                rotationZ = (1 - deal.value) * (if (index % 2 == 0) -8f else 8f)
            }
            .clip(RoundedCornerShape(14.dp))
            .background(if (order != null) Ds.Yellow else type.dark)
            .padding(if (order != null) 4.dp else 3.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(Brush.verticalGradient(listOf(type.color, type.color.copy(alpha = 0.7f), Color.White)))
            .clickable(enabled = enabled) {
                Sound.play(Sfx.Select)
                onClick()
            }
            .padding(8.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    p.name.prettyName(),
                    style = MaterialTheme.typography.titleSmall,
                    color = Ds.Ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text("PS ${stats["hp"] ?: "?"}", style = MaterialTheme.typography.labelMedium, color = Ds.RedDark)
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(1.25f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Brush.radialGradient(listOf(Color.White, type.color.copy(alpha = 0.35f))))
                    .border(2.dp, type.dark.copy(alpha = 0.6f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center,
            ) {
                AsyncImage(model = Sprites.artwork(p.id), contentDescription = p.name, modifier = Modifier.fillMaxSize().padding(4.dp))
                if (order != null) {
                    Box(
                        Modifier
                            .align(Alignment.TopStart)
                            .padding(4.dp)
                            .size(30.dp)
                            .clip(CircleShape)
                            .background(Ds.Red)
                            .border(3.dp, Color.White, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("$order", style = MaterialTheme.typography.headlineSmall, color = Color.White)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { p.types.orEmpty().forEach { TypeBadge(it) } }
            StatLine("ATQ", stats["attack"], Ds.Red)
            StatLine("DEF", stats["defense"], Ds.Blue)
            StatLine("VEL", stats["speed"], Ds.Green)
        }
    }
}

@Composable
private fun StatLine(label: String, value: Int?, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Ds.Ink, modifier = Modifier.size(28.dp, 14.dp))
        Box(
            Modifier
                .weight(1f)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Ds.Ink.copy(alpha = 0.15f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth(((value ?: 0) / 160f).coerceIn(0.03f, 1f))
                    .height(6.dp)
                    .background(color),
            )
        }
        Text("${value ?: "?"}", style = MaterialTheme.typography.labelSmall, color = Ds.Ink)
    }
}

/** Bottom tray with the 3 chosen Pokémon and the confirm / ready button. */
@Composable
private fun PartyTray(vm: GameViewModel) {
    DsPanel(Modifier.fillMaxWidth().padding(10.dp), accent = Ds.Red, padding = 10.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                for (slot in 0 until 3) {
                    val p = vm.selected.getOrNull(slot)?.let { id -> vm.pokemon.find { it.id == id } }
                    Box(
                        Modifier
                            .weight(1f)
                            .height(70.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (p != null) PokeTypes.style(p.types?.firstOrNull()).color.copy(alpha = 0.3f) else Ds.Ink.copy(alpha = 0.08f))
                            .border(2.dp, if (p != null) Ds.Red else Ds.Frame.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                            .clickable(enabled = p != null && !vm.readySent) {
                                Sound.play(Sfx.Select)
                                p?.let { vm.toggleSelection(it.id) }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (p != null) {
                            PixelSprite(Sprites.animatedFront(p.id), Sprites.front(p.id), pxScale = 1.1f)
                        } else {
                            Pokeball(size = 22.dp, greyed = true)
                        }
                        Text(
                            "${slot + 1}",
                            style = MaterialTheme.typography.labelMedium,
                            color = Ds.Ink,
                            modifier = Modifier.align(Alignment.TopStart).padding(4.dp),
                        )
                    }
                }
            }
            when {
                vm.readySent -> Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SpinningPokeball(24.dp)
                    Text(
                        if (vm.opponent?.ready == true) "  ¡Que empiece la batalla!" else "  Esperando a ${vm.opponent?.name ?: "tu rival"}…",
                        style = MaterialTheme.typography.titleMedium, color = Ds.Ink,
                    )
                }
                vm.teamSent -> PixelButton(
                    "¡LISTO PARA PELEAR!", onClick = vm::markReady, enabled = !vm.loading,
                    color = Ds.Green, dark = Ds.GreenDark, sfx = Sfx.Confirm, modifier = Modifier.fillMaxWidth(),
                )
                else -> PixelButton(
                    "CONFIRMAR EQUIPO (${vm.selected.size}/3)", onClick = vm::confirmTeam,
                    enabled = !vm.loading && vm.selected.size == 3, sfx = Sfx.Confirm, modifier = Modifier.fillMaxWidth(),
                )
            }
            Text(
                "Salir de la sala",
                style = MaterialTheme.typography.bodySmall,
                color = Ds.InkSoft,
                modifier = Modifier.align(Alignment.CenterHorizontally).clickable(onClick = vm::leaveRoom),
            )
        }
    }
}
