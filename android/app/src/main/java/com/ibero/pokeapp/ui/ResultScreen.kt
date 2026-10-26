package com.ibero.pokeapp.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.ui.components.DsPanel
import com.ibero.pokeapp.ui.components.OutlinedText
import com.ibero.pokeapp.ui.components.PixelButton
import com.ibero.pokeapp.ui.components.StripedBackground
import com.ibero.pokeapp.ui.theme.Ds
import com.ibero.pokeapp.ui.theme.Sprites
import kotlin.random.Random

@Composable
fun ResultScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val b = vm.battle
    val myScore = vm.myScore(b)
    val theirScore = vm.opponentScore(b)
    val won = vm.iWon(b)
    val pop = remember { Animatable(0f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow)) }

    StripedBackground(
        modifier,
        top = if (won) Color(0xFFF8B820) else Color(0xFF384058),
        bottom = if (won) Color(0xFFF87830) else Color(0xFF586078),
    ) {
        if (won) Confetti()
        Column(
            Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
        ) {
            Text(if (won) "🏆" else "💫", fontSize = 84.sp, modifier = Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value })
            OutlinedText(
                if (won) "¡VICTORIA!" else "DERROTA",
                MaterialTheme.typography.displayLarge,
                fill = if (won) Ds.Yellow else Color.White,
                outline = if (won) Ds.RedDark else Ds.Ink,
                outlineWidth = 14f,
                modifier = Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value },
            )
            DsPanel(Modifier.fillMaxWidth(0.88f), accent = if (won) Ds.Yellow else Ds.Frame) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Text("Ganador: ${b?.winner ?: "?"}", style = MaterialTheme.typography.titleLarge, color = Ds.Ink)
                    Text(
                        "${vm.playerName}  $myScore - $theirScore  ${vm.opponent?.name ?: "Rival"}",
                        style = MaterialTheme.typography.headlineSmall, color = Ds.Red, textAlign = TextAlign.Center,
                    )
                    b?.forfeitedBy?.let { side ->
                        Text(
                            if (side == vm.myKey) "Te rendiste" else "${vm.opponent?.name ?: "Tu rival"} se rindió",
                            style = MaterialTheme.typography.bodyMedium, color = Ds.InkSoft,
                        )
                    }
                    val team = vm.myTeam
                    if (team.isNotEmpty()) {
                        Spacer(Modifier.height(10.dp))
                        Text("Tu equipo", style = MaterialTheme.typography.bodyMedium, color = Ds.InkSoft)
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            team.forEach { AsyncImage(Sprites.artwork(it.id), it.name, Modifier.size(80.dp)) }
                        }
                    }
                }
            }
            PixelButton(
                "VOLVER AL INICIO", onClick = vm::leaveRoom, sfx = Sfx.Confirm,
                color = Ds.Blue, dark = Ds.BlueDark, modifier = Modifier.fillMaxWidth(0.88f),
            )
        }
    }
}

@Composable
private fun Confetti() {
    val t by rememberInfiniteTransition(label = "confetti").animateFloat(
        0f, 1f, infiniteRepeatable(tween(3500, easing = LinearEasing)), label = "t",
    )
    val pieces = remember {
        val r = Random(7)
        List(60) { floatArrayOf(r.nextFloat(), r.nextFloat(), r.nextFloat(), r.nextFloat()) }
    }
    val colors = listOf(Ds.Red, Ds.Yellow, Ds.Blue, Ds.Green, Color.White)
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            pieces.forEachIndexed { i, (x, start, speed, spin) ->
                val y = ((start + t * (0.6f + speed)) % 1f) * size.height * 1.1f - size.height * 0.05f
                val px = x * size.width + kotlin.math.sin((t * 6 + i).toDouble()).toFloat() * 14f
                rotate(t * 720 * (spin - 0.5f), Offset(px, y)) {
                    drawRect(colors[i % colors.size], Offset(px - 6f, y - 10f), Size(12f, 20f))
                }
            }
        }
    }
}
