package com.ibero.pokeapp.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.data.BattlePokemon
import com.ibero.pokeapp.data.Pokemon

@Composable
fun TeamSelectScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    LaunchedEffect(Unit) { vm.loadPokemon() }

    ScreenColumn(modifier) {
        Text("Elige tu equipo", style = MaterialTheme.typography.headlineMedium)
        Text("Sala ${vm.roomCode} · Toca 3 Pokémon en el orden en que van a pelear.")
        PlayerList(vm)
        ErrorText(vm.error)

        if (vm.pokemon.isEmpty()) {
            if (vm.loading) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text("Cargando Pokémon… (puede tardar unos segundos)")
                }
            } else {
                Button(onClick = vm::loadPokemon) { Text("Reintentar cargar Pokémon") }
            }
        }

        vm.pokemon.forEach { p ->
            val order = vm.selected.indexOf(p.id).takeIf { it >= 0 }?.plus(1)
            PokemonOption(p, order, enabled = !vm.readySent) { vm.toggleSelection(p.id) }
        }

        if (vm.pokemon.isNotEmpty()) {
            Text("Seleccionados: ${vm.selected.size}/3")
            when {
                vm.readySent -> Text(
                    if (vm.opponent?.ready == true) "¡Ambos listos! Iniciando batalla…" else "Listo ✅ Esperando al rival…",
                    fontWeight = FontWeight.Bold,
                )
                vm.teamSent -> Button(
                    onClick = vm::markReady,
                    enabled = !vm.loading,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Listo") }
                else -> Button(
                    onClick = vm::confirmTeam,
                    enabled = !vm.loading && vm.selected.size == 3,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Confirmar Equipo") }
            }
        }
        TextButton(onClick = vm::leaveRoom) { Text("Salir de la sala") }
    }
}

@Composable
private fun PokemonOption(p: Pokemon, order: Int?, enabled: Boolean, onClick: () -> Unit) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick),
        border = if (order != null) BorderStroke(3.dp, MaterialTheme.colorScheme.primary) else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Row(
            modifier = Modifier.padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            PokemonSprite(p.sprite, 64.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(p.name.displayName(), fontWeight = FontWeight.Bold)
                Text(p.types.orEmpty().joinToString(" / "), style = MaterialTheme.typography.bodySmall)
                val s = p.stats.orEmpty()
                Text(
                    "HP ${s["hp"] ?: "?"} · ATK ${s["attack"] ?: "?"} · DEF ${s["defense"] ?: "?"} · VEL ${s["speed"] ?: "?"}",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            if (order != null) {
                Text("#$order", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

@Composable
fun BattleScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val b = vm.battle
    ScreenColumn(modifier) {
        if (b == null) {
            Text("Cargando batalla…")
            ErrorText(vm.error)
            return@ScreenColumn
        }
        Text("Combate ${b.battleNumber} de 3", style = MaterialTheme.typography.headlineSmall)
        Text(
            "Tú ${vm.myScore(b)} - ${vm.opponentScore(b)} ${vm.opponent?.name ?: "Rival"}",
            style = MaterialTheme.typography.titleLarge,
        )
        ErrorText(vm.error)

        Text("Rival", style = MaterialTheme.typography.labelLarge)
        BattlePokemonCard(vm.opponentPokemon(b))
        Text("Tu Pokémon", style = MaterialTheme.typography.labelLarge)
        val mine = vm.myPokemon(b)
        BattlePokemonCard(mine)

        HorizontalDivider()
        when {
            b.status == "finished" -> Text("¡Combate terminado! El siguiente empieza en un momento…", fontWeight = FontWeight.Bold)
            vm.waitingForOpponent -> Text("Movimiento enviado. Esperando al rival…", fontWeight = FontWeight.Bold)
            else -> Text("Elige un movimiento:", fontWeight = FontWeight.Bold)
        }
        val canMove = b.status == "waiting_moves" && !vm.waitingForOpponent && !vm.loading
        mine?.moves.orEmpty().forEach { m ->
            Button(onClick = { vm.sendMove(m.id) }, enabled = canMove, modifier = Modifier.fillMaxWidth()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(m.name.displayName())
                    Text(
                        "${m.type ?: "?"} · Poder ${m.power ?: "-"} · Prec. ${m.accuracy ?: "-"}",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }

        b.lastTurn?.logs?.takeIf { it.isNotEmpty() }?.let { logs ->
            HorizontalDivider()
            Text("Último turno", style = MaterialTheme.typography.titleMedium)
            logs.forEach { Text("• $it") }
        }
    }
}

@Composable
private fun BattlePokemonCard(p: BattlePokemon?) {
    Card(modifier = Modifier.fillMaxWidth()) {
        if (p == null) {
            Text("—", modifier = Modifier.padding(12.dp))
            return@Card
        }
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PokemonSprite(spriteUrl(p.pokemonId), 72.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(p.name.displayName(), style = MaterialTheme.typography.titleMedium)
                LinearProgressIndicator(
                    progress = { if (p.maxHp > 0) p.hp.toFloat() / p.maxHp else 0f },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                )
                Text("HP ${p.hp} / ${p.maxHp}")
            }
        }
    }
}

@Composable
fun ResultScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val b = vm.battle
    val won = vm.myScore(b) > vm.opponentScore(b)
    ScreenColumn(modifier) {
        Text(
            if (won) "¡Ganaste! 🏆" else "Perdiste",
            fontSize = 40.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            "Ganador: ${b?.winner ?: "?"}",
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            "Marcador final: Tú ${vm.myScore(b)} - ${vm.opponentScore(b)} ${vm.opponent?.name ?: "Rival"}",
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        b?.lastTurn?.logs?.takeIf { it.isNotEmpty() }?.let { logs ->
            HorizontalDivider()
            Text("Último turno", style = MaterialTheme.typography.titleMedium)
            logs.forEach { Text("• $it") }
        }
        Button(onClick = vm::leaveRoom, modifier = Modifier.fillMaxWidth()) { Text("Volver al inicio") }
    }
}
