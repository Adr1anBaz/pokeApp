package com.ibero.pokeapp.ui.battle

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.data.Move
import com.ibero.pokeapp.data.MoveNames
import com.ibero.pokeapp.ui.components.Pokeball
import com.ibero.pokeapp.ui.components.TypeBadge
import com.ibero.pokeapp.ui.theme.Ds
import com.ibero.pokeapp.ui.theme.PokeTypes
import com.ibero.pokeapp.ui.theme.Sprites

private val CARD_GAP = 10.dp
private val MAX_CARD_HEIGHT = 165.dp

/**
 * The 4 moves as a 2x2 hand of cards in the same style as the team-selection cards:
 * a Card-Jitsu tab with the type symbol and a big power number, and a window with the details.
 */
@Composable
fun CardHand(vm: GameViewModel, d: BattleDirector, modifier: Modifier, onForfeit: () -> Unit) {
    val b = vm.battle
    val me = d.mine
    val canMove = !d.busy && b?.status == "waiting_moves" && b.winner == null && !vm.waitingForOpponent &&
        b.battleNumber == d.battleNumber && me?.visible == true && !vm.loading
    var played by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(canMove) { if (canMove) played = null }

    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color(0xFF3A4450), Ds.Ink)))
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        val hint = 26.dp
        val cardHeight = min((maxHeight - hint - CARD_GAP * 2) / 2, MAX_CARD_HEIGHT)
        Column(
            Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(CARD_GAP, Alignment.CenterVertically),
        ) {
            Box(Modifier.fillMaxWidth().height(hint)) {
                Text(
                    when {
                        canMove -> "▼ Elige un ataque ▼"
                        vm.waitingForOpponent -> "Esperando al rival…"
                        else -> ""
                    },
                    style = MaterialTheme.typography.titleSmall,
                    color = Ds.Yellow,
                    modifier = Modifier.align(Alignment.Center),
                )
                if (me != null && b?.winner == null) {
                    Text(
                        "RENDIRSE",
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .clip(RoundedCornerShape(6.dp))
                            .background(Ds.RedDark)
                            .border(1.5.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                            .clickable {
                                Sound.play(Sfx.Select)
                                onForfeit()
                            }
                            .padding(horizontal = 8.dp, vertical = 2.dp),
                    )
                }
            }
            val moves = me?.moves.orEmpty()
            for (row in 0 until 2) {
                Row(Modifier.fillMaxWidth().height(cardHeight), horizontalArrangement = Arrangement.spacedBy(CARD_GAP)) {
                    for (col in 0 until 2) {
                        val i = row * 2 + col
                        val m = moves.getOrNull(i)
                        val cell = Modifier.weight(1f).fillMaxHeight()
                        when {
                            vm.waitingForOpponent -> CardBack(i, cell)
                            m != null -> MoveCard(m, i, raised = canMove, played = played == m.id, foeTypes = d.theirs?.types, cell) {
                                played = m.id
                                vm.sendMove(m.id)
                            }
                            else -> Spacer(cell)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MoveCard(
    m: Move,
    index: Int,
    raised: Boolean,
    played: Boolean,
    foeTypes: List<String>?,
    modifier: Modifier,
    onPlay: () -> Unit,
) {
    val style = PokeTypes.style(m.type)
    val density = LocalDensity.current
    // -1 = played (flies up), 0 = in hand, 1 = lowered while the turn animates.
    val lift by animateFloatAsState(
        when {
            played -> -1f
            raised -> 0f
            else -> 1f
        },
        tween(if (played) 380 else 280, delayMillis = if (raised && !played) index * 60 else 0),
        label = "lift",
    )
    Row(
        modifier
            .graphicsLayer {
                translationY = with(density) { if (lift < 0) lift * 240.dp.toPx() else lift * 18.dp.toPx() }
                alpha = if (lift < 0) 1f + lift else 1f - lift * 0.45f
                scaleX = if (lift < 0) 1f - lift * 0.12f else 1f - lift * 0.04f
                scaleY = scaleX
                rotationZ = if (lift < 0) lift * 8f else 0f
            }
            .clip(RoundedCornerShape(14.dp))
            .background(Brush.verticalGradient(listOf(style.color, style.dark)))
            .border(2.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
            .clickable(enabled = raised && !played) {
                Sound.play(Sfx.Card)
                onPlay()
            }
            .padding(5.dp),
    ) {
        // Card-Jitsu tab: type symbol + big power number, sitting on the frame.
        Column(
            Modifier
                .width(58.dp)
                .fillMaxHeight()
                .padding(vertical = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceEvenly,
        ) {
            AsyncImage(
                Sprites.typeIcon(m.type), null,
                Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .border(2.dp, Color.White, RoundedCornerShape(10.dp)),
            )
            Text(
                "${m.power ?: "–"}",
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontSize = if ((m.power ?: 0) >= 100) 18.sp else 23.sp,
                    shadow = Shadow(Ds.Ink, offset = Offset(0f, 5f), blurRadius = 0f),
                ),
                color = Color.White,
            )
            Text("POTENCIA", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = Color.White)
        }
        // Window with the details, like the artwork window of the team cards.
        Column(
            Modifier
                .weight(1f)
                .fillMaxHeight()
                .clip(RoundedCornerShape(10.dp))
                .background(Brush.verticalGradient(listOf(Color.White, Color(0xFFF4F0E4), style.color.copy(alpha = 0.25f))))
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                MoveNames.name(m),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = Ds.Ink, maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 20.sp,
            )
            TypeBadge(m.type ?: "normal")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                ClassChip(m.damageClass)
                EffectivenessChip(PokeTypes.serverEffectiveness(m.type, foeTypes))
            }
            AccuracyBar(m.accuracy ?: 100, style.dark)
        }
    }
}

@Composable
private fun ClassChip(damageClass: String?) {
    val (label, color) = when (damageClass) {
        "special" -> "ESPECIAL" to Color(0xFF5060C0)
        "status" -> "ESTADO" to Ds.InkSoft
        else -> "FÍSICO" to Color(0xFFC05030)
    }
    Text(
        label,
        style = MaterialTheme.typography.labelSmall,
        maxLines = 1,
        softWrap = false,
        color = Color.White,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color)
            .padding(horizontal = 5.dp, vertical = 1.dp),
    )
}

@Composable
private fun AccuracyBar(accuracy: Int, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Text("PREC.", style = MaterialTheme.typography.labelSmall, color = Ds.Ink)
        Box(
            Modifier
                .weight(1f)
                .height(7.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Ds.Ink.copy(alpha = 0.15f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth((accuracy / 100f).coerceIn(0.05f, 1f))
                    .fillMaxHeight()
                    .background(color),
            )
        }
        Text("$accuracy%", style = MaterialTheme.typography.labelMedium, color = Ds.Ink)
    }
}

/** Hint against the current rival, computed the same way the server applies it. */
@Composable
private fun EffectivenessChip(eff: Double) {
    val (label, color) = when {
        eff > 1.0 -> "¡EFICAZ!" to Ds.Green
        eff < 1.0 -> "POCO EFICAZ" to Ds.InkSoft
        else -> return
    }
    Text(
        label,
        style = MaterialTheme.typography.labelSmall,
        maxLines = 1,
        softWrap = false,
        color = Color.White,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color)
            .padding(horizontal = 6.dp, vertical = 1.dp),
    )
}

@Composable
private fun CardBack(index: Int, modifier: Modifier) {
    val wobble by rememberInfiniteTransition(label = "wobble").animateFloat(
        -1f, 1f, infiniteRepeatable(tween(700, delayMillis = index * 120), RepeatMode.Reverse), label = "w",
    )
    Box(
        modifier
            .graphicsLayer { rotationZ = wobble * 1.5f; translationY = wobble * 3.dp.toPx() }
            .clip(RoundedCornerShape(14.dp))
            .background(Brush.verticalGradient(listOf(Ds.Red, Ds.RedDark)))
            .border(3.dp, Ds.Yellow.copy(alpha = 0.85f), RoundedCornerShape(14.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Pokeball(size = 46.dp)
    }
}
