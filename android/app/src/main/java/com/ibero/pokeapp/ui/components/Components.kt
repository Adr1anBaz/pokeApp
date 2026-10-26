package com.ibero.pokeapp.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.isSpecified
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.compose.rememberAsyncImagePainter
import coil.request.ImageRequest
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.ui.theme.Ds
import com.ibero.pokeapp.ui.theme.PokeTypes
import com.ibero.pokeapp.ui.theme.Sprites

/** Animated diagonal stripes, like the DS menus' backdrops. */
@Composable
fun StripedBackground(
    modifier: Modifier = Modifier,
    top: Color = Color(0xFFE85040),
    bottom: Color = Color(0xFFF8A040),
    content: @Composable BoxScope.() -> Unit,
) {
    val shift by rememberInfiniteTransition(label = "stripes").animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(6000, easing = LinearEasing)), label = "shift",
    )
    Box(
        modifier = modifier
            .fillMaxSize()
            .clipToBounds()  // keep the stripes out of the status and navigation bars
            .background(Brush.verticalGradient(listOf(top, bottom)))
            .drawBehind {
                val gap = 48.dp.toPx()
                val offset = shift * gap * 2
                var x = -size.height + offset - gap * 2
                while (x < size.width + gap) {
                    drawLine(
                        Color.White.copy(alpha = 0.10f),
                        start = Offset(x, size.height), end = Offset(x + size.height, 0f),
                        strokeWidth = gap * 0.45f,
                    )
                    x += gap
                }
            },
        content = content,
    )
}

/** White dialog panel with the double frame DS games use. */
@Composable
fun DsPanel(
    modifier: Modifier = Modifier,
    accent: Color = Ds.Blue,
    padding: Dp = 14.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .border(3.dp, Ds.Frame, RoundedCornerShape(12.dp))
            .padding(3.dp)
            .border(3.dp, accent, RoundedCornerShape(9.dp))
            .clip(RoundedCornerShape(9.dp))
            .background(Ds.Paper)
            .padding(padding),
        content = content,
    )
}

/** Chunky button with a bottom "3D" edge that sinks when pressed. */
@Composable
fun PixelButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = Ds.Red,
    dark: Color = Ds.RedDark,
    enabled: Boolean = true,
    sfx: Sfx = Sfx.Select,
    textStyle: TextStyle = MaterialTheme.typography.headlineSmall,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val depth = if (pressed && enabled) 1.dp else 5.dp
    val face = if (enabled) color else Color(0xFFB8B8B8)
    val edge = if (enabled) dark else Color(0xFF888888)
    Box(
        modifier = modifier
            .padding(top = 5.dp - depth)
            .clip(RoundedCornerShape(12.dp))
            .background(edge)
            .padding(bottom = depth)
            .clip(RoundedCornerShape(12.dp))
            .background(Brush.verticalGradient(listOf(face.copy(alpha = 0.85f), face)))
            .border(2.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
            .clickable(interaction, indication = null, enabled = enabled) {
                Sound.play(sfx)
                onClick()
            }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = textStyle, color = Color.White, textAlign = TextAlign.Center)
    }
}

/** Text with a thick outline, used for the logo and big headings. */
@Composable
fun OutlinedText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    fill: Color = Ds.Yellow,
    outline: Color = Ds.BlueDark,
    outlineWidth: Float = 10f,
) {
    Box(modifier) {
        Text(
            text,
            style = style.copy(drawStyle = Stroke(width = outlineWidth)),
            color = outline,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(text, style = style, color = fill, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
}

/** A Poké Ball drawn in code so it can spin, grey out or flash. */
@Composable
fun Pokeball(modifier: Modifier = Modifier, size: Dp = 24.dp, greyed: Boolean = false, rotation: Float = 0f) {
    val top = if (greyed) Color(0xFF9A9A9A) else Ds.Red
    Canvas(modifier.size(size).rotate(rotation)) {
        val r = this.size.minDimension / 2
        val c = center
        val line = r * 0.16f
        drawCircle(Color.White, r, c)
        clipRect(bottom = c.y) { drawCircle(top, r, c) }
        drawCircle(Ds.Ink, r, c, style = Stroke(line))
        drawLine(Ds.Ink, Offset(c.x - r, c.y), Offset(c.x + r, c.y), strokeWidth = line)
        drawCircle(Ds.Ink, r * 0.36f, c)
        drawCircle(Color.White, r * 0.22f, c)
    }
}

@Composable
fun SpinningPokeball(size: Dp = 28.dp, modifier: Modifier = Modifier) {
    val angle by rememberInfiniteTransition(label = "spin").animateFloat(
        0f, 360f, infiniteRepeatable(tween(900, easing = LinearEasing)), label = "angle",
    )
    Pokeball(modifier, size, rotation = angle)
}

/** DS HP bar. [hp] is a float so it can be animated smoothly as damage drains it. */
@Composable
fun HpBar(hp: Float, maxHp: Int, modifier: Modifier = Modifier) {
    val fraction = if (maxHp > 0) (hp / maxHp).coerceIn(0f, 1f) else 0f
    val color = when {
        fraction > 0.5f -> Ds.HpGreen
        fraction > 0.2f -> Ds.HpYellow
        else -> Ds.HpRed
    }
    Box(
        modifier
            .height(12.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(Ds.Ink)
            .padding(2.dp),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(4.dp))
                .background(Color(0xFF506058)),
        )
        Box(
            Modifier
                .fillMaxWidth(fraction)
                .fillMaxSize()
                .clip(RoundedCornerShape(4.dp))
                .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.75f), color, color))),
        )
    }
}

@Composable
fun TypeBadge(type: String, modifier: Modifier = Modifier, style: TextStyle = MaterialTheme.typography.labelSmall) {
    val s = PokeTypes.style(type)
    Row(
        modifier
            .clip(RoundedCornerShape(6.dp))
            .background(s.color)
            .border(1.5.dp, s.dark, RoundedCornerShape(6.dp))
            .padding(start = 2.dp, end = 6.dp, top = 1.dp, bottom = 1.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        AsyncImage(Sprites.typeIcon(type), null, Modifier.size(14.dp).clip(RoundedCornerShape(3.dp)))
        Text(s.es.uppercase(), style = style, color = Color.White)
    }
}

/**
 * Pixel-art sprite drawn at [pxScale] times its original size, so every Pokémon keeps its
 * real proportions. Falls back to [fallbackUrl] (static sprite) when the animated one is missing.
 */
@Composable
fun PixelSprite(
    url: String,
    fallbackUrl: String?,
    pxScale: Float,
    modifier: Modifier = Modifier,
    tint: Color = Color.Transparent,
) {
    val context = LocalContext.current
    var useFallback by remember(url) { mutableStateOf(false) }
    val request = remember(url, useFallback) {
        ImageRequest.Builder(context)
            .data(if (useFallback && fallbackUrl != null) fallbackUrl else url)
            .size(coil.size.Size.ORIGINAL)
            .build()
    }
    val painter = rememberAsyncImagePainter(
        model = request,
        onError = { if (!useFallback && fallbackUrl != null) useFallback = true },
        filterQuality = FilterQuality.None,
    )
    val intrinsic = painter.intrinsicSize
    val density = LocalDensity.current
    val size = if (intrinsic.isSpecified && intrinsic.width > 1f) {
        with(density) { Size(intrinsic.width * pxScale, intrinsic.height * pxScale).let { it.width.toDp() to it.height.toDp() } }
    } else {
        1.dp to 1.dp
    }
    Image(
        painter = painter,
        contentDescription = null,
        contentScale = ContentScale.FillBounds,
        colorFilter = if (tint.alpha > 0f) ColorFilter.tint(tint, BlendMode.SrcAtop) else null,
        modifier = modifier.requiredSize(size.first, size.second),
    )
}

@Composable
fun ErrorBanner(message: String?, modifier: Modifier = Modifier) {
    if (message == null) return
    Text(
        message,
        style = MaterialTheme.typography.bodyMedium,
        color = Color.White,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Ds.RedDark.copy(alpha = 0.92f))
            .border(2.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp),
    )
}
