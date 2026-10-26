package com.ibero.pokeapp.ui.battle

import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ibero.pokeapp.GameViewModel
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.data.Move
import com.ibero.pokeapp.data.MoveNames
import com.ibero.pokeapp.ui.components.DsPanel
import com.ibero.pokeapp.ui.components.ErrorBanner
import com.ibero.pokeapp.ui.components.HpBar
import com.ibero.pokeapp.ui.components.OutlinedText
import com.ibero.pokeapp.ui.components.PixelButton
import com.ibero.pokeapp.ui.components.PixelSprite
import com.ibero.pokeapp.ui.components.Pokeball
import com.ibero.pokeapp.ui.components.SpinningPokeball
import com.ibero.pokeapp.ui.theme.Ds
import com.ibero.pokeapp.ui.theme.PokeTypes
import com.ibero.pokeapp.ui.theme.Sprites
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun BattleScreen(vm: GameViewModel, modifier: Modifier = Modifier) {
    val view = LocalView.current
    val director = remember {
        BattleDirector(
            mySide = vm.myKey,
            rivalName = { vm.opponent?.name ?: "Rival" },
            onHit = { strong ->
                view.performHapticFeedback(if (strong) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.VIRTUAL_KEY)
            },
            onFinished = vm::showResult,
        )
    }
    LaunchedEffect(director) { director.run() }
    LaunchedEffect(vm.battle) { vm.battle?.let(director::onServerState) }

    var confirmForfeit by remember { mutableStateOf(false) }
    val matchOver = vm.battle?.winner != null
    // The system back button asks to forfeit instead of leaving the battle silently.
    BackHandler(enabled = !matchOver) { confirmForfeit = !confirmForfeit }
    if (matchOver) confirmForfeit = false

    Box(modifier.fillMaxSize().background(Ds.Ink)) {
        Column(Modifier.fillMaxSize()) {
            TopBar(vm, director)
            Scene(director)
            MessageBox(vm, director)
            ErrorBanner(vm.error, Modifier.padding(horizontal = 10.dp))
            CardHand(vm, director, Modifier.weight(1f), onForfeit = { confirmForfeit = true })
        }
        if (director.showVs) VsOverlay(vm, director)
        if (confirmForfeit) {
            ForfeitDialog(
                rival = vm.opponent?.name ?: "tu rival",
                loading = vm.loading,
                onConfirm = vm::forfeit,
                onDismiss = { confirmForfeit = false },
            )
        }
        if (director.flash.value > 0f) {
            Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = director.flash.value)))
        }
        if (vm.battle == null) {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                SpinningPokeball(56.dp)
                Text("Preparando batalla…", style = MaterialTheme.typography.titleLarge, color = Color.White)
            }
        }
    }
}

// ---------------- Top bar ----------------

@Composable
private fun TopBar(vm: GameViewModel, d: BattleDirector) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color(0xFF384048), Ds.Ink)))
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PartyBalls(fainted = d.theirScore)
        Text(
            " ${vm.playerName}",
            style = MaterialTheme.typography.labelMedium, color = Color.White, maxLines = 1,
            overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
        )
        Text(
            if (d.battleNumber > 0) "COMBATE ${d.battleNumber}/3" else "",
            style = MaterialTheme.typography.headlineSmall.copy(fontSize = 11.sp), color = Ds.Yellow,
        )
        Text(
            "${vm.opponent?.name ?: "Rival"} ",
            style = MaterialTheme.typography.labelMedium, color = Color.White, maxLines = 1,
            overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End, modifier = Modifier.weight(1f),
        )
        PartyBalls(fainted = d.myScore)
        Text(
            if (Sound.muted) " 🔇" else " 🔊",
            fontSize = 18.sp,
            modifier = Modifier.clickable { Sound.toggleMute() },
        )
    }
}

/** The 3 Poké Balls of a party; fainted ones are greyed out. */
@Composable
private fun PartyBalls(fainted: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        repeat(3) { Pokeball(size = 14.dp, greyed = it < fainted) }
    }
}

// ---------------- Scene ----------------

@Composable
private fun Scene(d: BattleDirector) {
    val drift by rememberInfiniteTransition(label = "sky").animateFloat(
        0f, 1f, infiniteRepeatable(tween(5000, easing = LinearEasing)), label = "drift",
    )
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .aspectRatio(1.15f)
            .graphicsLayer { translationX = d.shake.value * 10.dp.toPx(); clip = true },
    ) {
        val density = LocalDensity.current
        val wPx = with(density) { maxWidth.toPx() }
        val hPx = with(density) { maxHeight.toPx() }
        Anchors.width = wPx
        Anchors.height = hPx

        Canvas(Modifier.fillMaxSize()) { drawBackdrop(drift) }

        // Showdown back sprites are drawn bigger than the front ones, so yours gets a smaller factor.
        d.theirs?.let { MonSprite(it, Side.Theirs, pxScale = wPx / 215f, wPx, hPx) }
        d.mine?.let { MonSprite(it, Side.Mine, pxScale = wPx / 270f, wPx, hPx) }

        Canvas(Modifier.fillMaxSize()) {
            d.ball?.let { drawThrownBall(it) }
            d.effect?.let { it.effect.draw(this, it.progress.value, size.width / 10f) }
        }

        d.theirs?.let { v ->
            HpBox(v, Side.Theirs, fainted = d.myScore, Modifier.align(Alignment.TopStart).padding(top = 10.dp, start = 8.dp).fillMaxWidth(0.56f))
        }
        d.mine?.let { v ->
            HpBox(
                v, Side.Mine, fainted = d.theirScore,
                Modifier.align(Alignment.TopEnd).padding(top = maxHeight * 0.60f, end = 8.dp).fillMaxWidth(0.54f),
            )
        }
    }
}

/** Places content so its bottom-center sits at ([fx], [fy]) of the parent. */
private fun Modifier.anchoredAt(fx: Float, fy: Float) = layout { measurable, constraints ->
    val p = measurable.measure(constraints.copy(minWidth = 0, minHeight = 0))
    layout(constraints.maxWidth, constraints.maxHeight) {
        p.place((constraints.maxWidth * fx - p.width / 2f).roundToInt(), (constraints.maxHeight * fy - p.height).roundToInt())
    }
}

@Composable
private fun MonSprite(v: MonView, side: Side, pxScale: Float, wPx: Float, hPx: Float) {
    if (!v.visible) return
    val mine = side == Side.Mine
    // Gentle idle bob, like the DS games.
    val bob by rememberInfiniteTransition(label = "bob").animateFloat(
        0f, 1f, infiniteRepeatable(tween(if (mine) 900 else 1100), RepeatMode.Reverse), label = "bob",
    )
    Box(
        Modifier
            .fillMaxSize()
            .anchoredAt(if (mine) Anchors.MY_X else Anchors.THEIR_X, if (mine) Anchors.MY_Y else Anchors.THEIR_Y)
            .graphicsLayer {
                transformOrigin = TransformOrigin(0.5f, 1f)
                translationX = v.dx.value * wPx
                translationY = v.dy.value * hPx - bob * 3.dp.toPx()
                scaleX = v.scale.value
                scaleY = v.scale.value
                alpha = v.alpha.value
            },
    ) {
        PixelSprite(
            url = if (mine) Sprites.animatedBack(v.id) else Sprites.animatedFront(v.id),
            fallbackUrl = if (mine) Sprites.back(v.id) else Sprites.front(v.id),
            pxScale = pxScale,
            tint = v.tint,
        )
    }
}

private fun DrawScope.drawBackdrop(drift: Float) {
    val w = size.width
    val h = size.height
    val horizon = h * 0.56f
    drawRect(Brush.verticalGradient(listOf(Ds.SkyTop, Ds.SkyBottom), endY = horizon), size = Size(w, horizon))
    // Speed lines drifting across the sky (image 1 vibe).
    val lines = listOf(0.08f to 0.5f, 0.17f to 0.3f, 0.27f to 0.6f, 0.36f to 0.25f, 0.45f to 0.45f)
    lines.forEachIndexed { i, (y, len) ->
        val x = ((drift + i * 0.37f) % 1f) * (w * 1.6f) - w * 0.6f
        drawRoundRect(
            Color.White.copy(alpha = 0.45f), topLeft = Offset(x, h * y), size = Size(w * len, h * 0.022f),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(h * 0.011f),
        )
    }
    drawRect(
        Brush.verticalGradient(listOf(Color(0xFFA8E080), Color(0xFF70B850)), startY = horizon, endY = h),
        topLeft = Offset(0f, horizon), size = Size(w, h - horizon),
    )
    // Grass stripes in the field.
    for (k in 0 until 6) {
        val y = horizon + (h - horizon) * (k / 6f)
        drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, y), Size(w, (h - horizon) / 12f))
    }
    drawPlatform(Offset(Anchors.THEIR_X * w, Anchors.THEIR_Y * h - h * 0.01f), Size(w * 0.48f, h * 0.11f))
    drawPlatform(Offset(Anchors.MY_X * w, Anchors.MY_Y * h - h * 0.02f), Size(w * 0.64f, h * 0.14f))
}

private fun DrawScope.drawPlatform(center: Offset, s: Size) {
    val topLeft = Offset(center.x - s.width / 2, center.y - s.height / 2)
    drawOval(Ds.GrassDark, topLeft + Offset(0f, s.height * 0.12f), s)
    drawOval(Ds.Grass, topLeft, s)
    drawOval(Color(0xFFA0E070), topLeft + Offset(s.width * 0.12f, s.height * 0.12f), Size(s.width * 0.76f, s.height * 0.6f))
    // Grass tufts around the rim.
    for (k in 0 until 9) {
        val a = Math.PI * (0.05 + 0.9 * k / 8)
        val x = center.x - kotlin.math.cos(a).toFloat() * s.width * 0.47f
        val y = center.y - sin(a).toFloat() * s.height * 0.42f
        val path = Path().apply {
            moveTo(x - s.height * 0.12f, y); lineTo(x, y - s.height * 0.3f); lineTo(x + s.height * 0.12f, y); close()
        }
        drawPath(path, Ds.GrassDark)
    }
}

private fun DrawScope.drawThrownBall(b: BallThrow) {
    val t = b.progress.value
    val w = size.width
    val h = size.height
    val (start, end) = if (b.side == Side.Mine) {
        Offset(-0.05f * w, 0.9f * h) to Offset(Anchors.MY_X * w, (Anchors.MY_Y - 0.15f) * h)
    } else {
        Offset(1.05f * w, 0.05f * h) to Offset(Anchors.THEIR_X * w, (Anchors.THEIR_Y - 0.1f) * h)
    }
    val pos = Offset(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t - sin(t * Math.PI).toFloat() * h * 0.3f)
    val r = w * 0.035f
    rotate(t * 720f, pos) {
        drawCircle(Color.White, r, pos)
        clipRect(top = pos.y - r, bottom = pos.y) { drawCircle(Ds.Red, r, pos) }
        drawCircle(Ds.Ink, r, pos, style = Stroke(r * 0.18f))
        drawLine(Ds.Ink, Offset(pos.x - r, pos.y), Offset(pos.x + r, pos.y), r * 0.18f)
        drawCircle(Ds.Ink, r * 0.35f, pos)
        drawCircle(Color.White, r * 0.2f, pos)
    }
}

/** DS-style status box: name, party, HP bar (and numbers for your own Pokémon). */
@Composable
private fun HpBox(v: MonView, side: Side, fainted: Int, modifier: Modifier) {
    var shown by remember(v) { mutableStateOf(false) }
    LaunchedEffect(v.visible) { if (v.visible) shown = true }
    val mine = side == Side.Mine
    AnimatedVisibility(shown, modifier, enter = slideInHorizontally { if (mine) it else -it } + fadeIn()) {
        val shape = if (mine) RoundedCornerShape(topStart = 14.dp, bottomStart = 4.dp, topEnd = 4.dp, bottomEnd = 4.dp)
        else RoundedCornerShape(topEnd = 14.dp, bottomEnd = 4.dp, topStart = 4.dp, bottomStart = 4.dp)
        Column(
            Modifier
                .clip(shape)
                .background(Ds.Frame)
                .padding(3.dp)
                .clip(shape)
                .background(Brush.verticalGradient(listOf(Color(0xFFF8F8E8), Color(0xFFE0E0C8))))
                .padding(horizontal = 10.dp, vertical = 6.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    v.name, style = MaterialTheme.typography.titleSmall, color = Ds.Ink,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
                )
                v.types.take(2).forEach {
                    Box(
                        Modifier
                            .padding(start = 3.dp)
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(PokeTypes.style(it).color)
                            .border(1.dp, Ds.Ink, CircleShape),
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "PS", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = Ds.Yellow,
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(Ds.Ink)
                        .padding(horizontal = 4.dp),
                )
                Spacer(Modifier.width(4.dp))
                HpBar(v.hp.value, v.maxHp, Modifier.weight(1f))
            }
            if (mine) {
                Text(
                    "${v.hp.value.roundToInt()} / ${v.maxHp}",
                    style = MaterialTheme.typography.titleSmall, color = Ds.Ink,
                    textAlign = TextAlign.End, modifier = Modifier.fillMaxWidth(),
                )
            } else {
                Row(Modifier.padding(top = 3.dp)) { PartyBalls(fainted) }
            }
        }
    }
}

// ---------------- Dialog ----------------

@Composable
private fun MessageBox(vm: GameViewModel, d: BattleDirector) {
    val b = vm.battle
    val text = when {
        d.busy -> d.message.take(d.visibleChars)
        b?.winner != null -> d.message
        vm.waitingForOpponent -> "Esperando a ${vm.opponent?.name ?: "tu rival"}…"
        b?.status == "finished" -> "Preparando el siguiente combate…"
        d.mine != null -> "¿Qué hará ${d.mine!!.name}?"
        else -> ""
    }
    val arrow by rememberInfiniteTransition(label = "arrow").animateFloat(
        0f, 1f, infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "a",
    )
    DsPanel(Modifier.fillMaxWidth().height(92.dp).padding(horizontal = 6.dp, vertical = 4.dp), accent = Ds.Red, padding = 10.dp) {
        Text(text, style = MaterialTheme.typography.titleLarge, color = Ds.Ink, modifier = Modifier.fillMaxWidth())
        if (d.busy && d.visibleChars >= d.message.length) {
            Text(
                "▼", color = Ds.Red, fontSize = 14.sp,
                modifier = Modifier.align(Alignment.BottomEnd).graphicsLayer { translationY = arrow * 4.dp.toPx() },
            )
        }
        if (!d.busy && vm.waitingForOpponent) {
            SpinningPokeball(22.dp, Modifier.align(Alignment.BottomEnd))
        }
    }
}

// ---------------- Forfeit ----------------

@Composable
private fun ForfeitDialog(rival: String, loading: Boolean, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.6f))
            .clickable(enabled = !loading, onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        DsPanel(Modifier.fillMaxWidth(0.86f).clickable(enabled = false) {}, accent = Ds.Red) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("¿RENDIRTE?", style = MaterialTheme.typography.headlineMedium, color = Ds.Red)
                Text(
                    "Perderás la partida y $rival será el ganador.",
                    style = MaterialTheme.typography.bodyLarge, color = Ds.Ink, textAlign = TextAlign.Center,
                )
                PixelButton(
                    if (loading) "RINDIÉNDOSE…" else "SÍ, RENDIRME", onClick = onConfirm, enabled = !loading,
                    modifier = Modifier.fillMaxWidth(),
                )
                PixelButton(
                    "SEGUIR PELEANDO", onClick = onDismiss, enabled = !loading,
                    color = Ds.Blue, dark = Ds.BlueDark, modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

// ---------------- VS splash ----------------

@Composable
private fun VsOverlay(vm: GameViewModel, d: BattleDirector) {
    val p = d.vs.value
    val leads = d.vsLeads
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = with(LocalDensity.current) { maxWidth.toPx() }
        Canvas(Modifier.fillMaxSize()) {
            val top = Path().apply { moveTo(0f, 0f); lineTo(size.width, 0f); lineTo(size.width, size.height * 0.42f); lineTo(0f, size.height * 0.58f); close() }
            val bottom = Path().apply { moveTo(0f, size.height * 0.58f); lineTo(size.width, size.height * 0.42f); lineTo(size.width, size.height); lineTo(0f, size.height); close() }
            drawPath(top, Brush.verticalGradient(listOf(Ds.Blue, Ds.BlueDark)))
            drawPath(bottom, Brush.verticalGradient(listOf(Ds.RedDark, Ds.Red)))
            drawLine(Color.White, Offset(0f, size.height * 0.58f), Offset(size.width, size.height * 0.42f), 8.dp.toPx())
        }
        // Rival comes in from the right (top half), you from the left (bottom half).
        Column(
            Modifier
                .align(Alignment.TopEnd)
                .padding(top = 70.dp, end = 20.dp)
                .graphicsLayer { translationX = (1f - p) * w },
            horizontalAlignment = Alignment.End,
        ) {
            leads?.let { AsyncImage(Sprites.artwork(it.second), null, Modifier.size(170.dp)) }
            OutlinedText(vm.opponent?.name ?: "Rival", MaterialTheme.typography.headlineMedium, fill = Color.White, outline = Ds.BlueDark)
        }
        Column(
            Modifier
                .align(Alignment.BottomStart)
                .padding(bottom = 70.dp, start = 20.dp)
                .graphicsLayer { translationX = (p - 1f) * w },
        ) {
            OutlinedText(vm.playerName, MaterialTheme.typography.headlineMedium, fill = Color.White, outline = Ds.RedDark)
            leads?.let { AsyncImage(Sprites.artwork(it.first), null, Modifier.size(170.dp)) }
        }
        OutlinedText(
            "VS",
            MaterialTheme.typography.displayLarge.copy(fontSize = 64.sp, lineHeight = 70.sp),
            modifier = Modifier
                .align(Alignment.Center)
                .graphicsLayer { scaleX = p * 1.1f; scaleY = p * 1.1f; rotationZ = (1f - p) * -40f },
            outlineWidth = 18f,
        )
    }
}
