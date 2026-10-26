package com.ibero.pokeapp.ui.battle

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import com.ibero.pokeapp.ui.theme.PokeTypes
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** How a move's impact looks; chosen from its type. */
private enum class Pattern { Flames, Bubbles, Bolt, Leaves, Shards, Rings, Shadow, Rocks, Wind, Swarm, Sparkle, Burst }

private fun patternFor(type: String?) = when (type) {
    "fire", "dragon" -> Pattern.Flames
    "water", "poison" -> Pattern.Bubbles
    "electric" -> Pattern.Bolt
    "grass" -> Pattern.Leaves
    "ice" -> Pattern.Shards
    "psychic" -> Pattern.Rings
    "ghost", "dark" -> Pattern.Shadow
    "rock", "ground" -> Pattern.Rocks
    "flying" -> Pattern.Wind
    "bug" -> Pattern.Swarm
    "fairy" -> Pattern.Sparkle
    else -> Pattern.Burst
}

/** One attack's visual: an optional projectile (special moves) followed by an impact at the target. */
class AttackEffect(val type: String?, val special: Boolean, val from: Offset, val to: Offset, seed: Int) {
    private val pattern = patternFor(type)
    private val color = PokeTypes.style(type).color
    private val dark = PokeTypes.style(type).dark
    private val rnd = Random(seed)
    // Pre-rolled particle parameters so every frame draws the same particles.
    private val particles = List(18) { Particle(rnd.nextFloat(), rnd.nextFloat(), rnd.nextFloat(), rnd.nextFloat()) }

    private data class Particle(val a: Float, val b: Float, val c: Float, val d: Float)

    /** [p] goes 0..1 over the whole effect; [unit] is a scale reference (scene width / 10). */
    fun draw(scope: DrawScope, p: Float, unit: Float) = with(scope) {
        val impactStart = if (special) 0.4f else 0f
        if (special && p < impactStart) {
            val t = p / impactStart
            val pos = Offset(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t - sin(t * PI).toFloat() * unit * 0.8f)
            drawCircle(color.copy(alpha = 0.35f), unit * 0.55f, pos)
            drawCircle(color, unit * 0.35f, pos)
            drawCircle(Color.White, unit * 0.15f, pos)
            return@with
        }
        val t = ((p - impactStart) / (1f - impactStart)).coerceIn(0f, 1f)
        when (pattern) {
            Pattern.Flames -> particles.forEach { q ->
                val x = to.x + (q.a - 0.5f) * unit * 2.2f
                val y = to.y + unit * 0.8f - t * unit * (1.2f + q.b * 1.6f)
                val r = unit * (0.25f + q.c * 0.35f) * (1f - t * 0.8f)
                drawCircle(Color(0xFFFFE070).copy(alpha = 1f - t), r * 0.55f, Offset(x, y))
                drawCircle(color.copy(alpha = (1f - t) * 0.8f), r, Offset(x, y + r * 0.3f))
            }
            Pattern.Bubbles -> particles.forEachIndexed { i, q ->
                val angle = q.a * 2 * PI
                val dist = t * unit * (0.8f + q.b * 1.4f)
                val c = Offset(to.x + cos(angle).toFloat() * dist, to.y + sin(angle).toFloat() * dist - t * unit * 0.4f)
                val r = unit * (0.15f + q.c * 0.25f)
                drawCircle(color.copy(alpha = (1f - t) * 0.5f), r, c)
                drawCircle(Color.White.copy(alpha = 1f - t), r, c, style = Stroke(unit * 0.05f))
                if (i % 3 == 0) drawCircle(Color.White.copy(alpha = 1f - t), r * 0.3f, c - Offset(r * 0.3f, r * 0.3f))
            }
            Pattern.Bolt -> {
                val flicker = ((t * 9).toInt() % 2 == 0)
                if (t < 0.85f && flicker) {
                    repeat(3) { k ->
                        val path = Path()
                        var x = to.x + (particles[k].a - 0.5f) * unit * 1.5f
                        var y = to.y - unit * 3.5f
                        path.moveTo(x, y)
                        for (s in 0 until 6) {
                            x += (particles[(k * 5 + s) % particles.size].b - 0.5f) * unit * 1.2f
                            y += unit * 0.62f
                            path.lineTo(x, y)
                        }
                        drawPath(path, Color.White, style = Stroke(unit * 0.22f, cap = StrokeCap.Round))
                        drawPath(path, color, style = Stroke(unit * 0.12f, cap = StrokeCap.Round))
                    }
                }
                drawCircle(color.copy(alpha = (1f - t) * 0.5f), unit * (0.5f + t * 1.5f), to)
            }
            Pattern.Leaves -> particles.forEach { q ->
                val angle = q.a * 2 * PI + t * 4
                val dist = unit * (0.3f + t * (1.2f + q.b))
                val c = Offset(to.x + cos(angle).toFloat() * dist, to.y + sin(angle).toFloat() * dist * 0.7f)
                rotate(degrees = (angle * 57.3f).toFloat() + t * 360, pivot = c) {
                    drawOval(
                        if (q.c > 0.5f) color else dark,
                        topLeft = c - Offset(unit * 0.28f, unit * 0.12f),
                        size = Size(unit * 0.56f, unit * 0.24f),
                        alpha = 1f - t * 0.7f,
                    )
                }
            }
            Pattern.Shards -> particles.forEach { q ->
                val angle = q.a * 2 * PI
                val dist = unit * t * (1.2f + q.b * 1.5f)
                val c = Offset(to.x + cos(angle).toFloat() * dist, to.y + sin(angle).toFloat() * dist)
                val s = unit * (0.18f + q.c * 0.2f)
                val path = Path().apply {
                    moveTo(c.x, c.y - s * 1.6f); lineTo(c.x + s, c.y); lineTo(c.x, c.y + s * 1.6f); lineTo(c.x - s, c.y); close()
                }
                drawPath(path, Color.White.copy(alpha = 1f - t))
                drawPath(path, color.copy(alpha = 1f - t), style = Stroke(unit * 0.06f))
            }
            Pattern.Rings -> repeat(4) { k ->
                val tt = (t * 1.6f - k * 0.2f).coerceIn(0f, 1f)
                if (tt > 0f) drawCircle(color.copy(alpha = 1f - tt), unit * (0.2f + tt * 2f), to, style = Stroke(unit * 0.16f))
            }
            Pattern.Shadow -> {
                drawCircle(Color(0xFF201030).copy(alpha = (sin(t * PI).toFloat()) * 0.55f), unit * 2.2f, to)
                particles.forEach { q ->
                    val angle = q.a * 2 * PI
                    val dist = unit * (2.2f - t * 2f) * (0.6f + q.b * 0.6f)
                    val c = Offset(to.x + cos(angle).toFloat() * dist, to.y + sin(angle).toFloat() * dist)
                    drawCircle(color.copy(alpha = sin(t * PI).toFloat()), unit * (0.15f + q.c * 0.2f), c)
                }
            }
            Pattern.Rocks -> particles.take(9).forEach { q ->
                val delay = q.d * 0.4f
                val tt = ((t - delay) / 0.6f).coerceIn(0f, 1f)
                if (tt <= 0f) return@forEach
                val x = to.x + (q.a - 0.5f) * unit * 2.4f
                val y = to.y - unit * 3f + tt * unit * (3f + q.b * 0.6f)
                val s = unit * (0.25f + q.c * 0.3f)
                rotate(tt * 200 * (q.a - 0.5f), Offset(x, y)) {
                    drawRect(dark, Offset(x - s / 2, y - s / 2), Size(s, s), alpha = 1f - (tt - 0.8f).coerceAtLeast(0f) * 5)
                    drawRect(color, Offset(x - s / 2, y - s / 2), Size(s * 0.6f, s * 0.6f), alpha = 1f - (tt - 0.8f).coerceAtLeast(0f) * 5)
                }
            }
            Pattern.Wind -> repeat(5) { k ->
                val tt = (t * 1.4f - k * 0.08f).coerceIn(0f, 1f)
                val y = to.y + (k - 2) * unit * 0.45f
                val x0 = to.x - unit * 2.5f + tt * unit * 3.5f
                drawArc(
                    Color.White.copy(alpha = (1f - tt)), startAngle = 200f, sweepAngle = 140f, useCenter = false,
                    topLeft = Offset(x0, y - unit * 0.4f), size = Size(unit * 1.6f, unit * 0.8f), style = Stroke(unit * 0.12f, cap = StrokeCap.Round),
                )
            }
            Pattern.Swarm -> particles.forEach { q ->
                val angle = q.a * 2 * PI + t * 10 * (if (q.b > 0.5f) 1 else -1)
                val dist = unit * (0.6f + q.c * 0.9f) * (1f - t * 0.5f)
                drawCircle(dark.copy(alpha = 1f - t * 0.6f), unit * 0.1f, Offset(to.x + cos(angle).toFloat() * dist, to.y + sin(angle).toFloat() * dist * 0.6f))
            }
            Pattern.Sparkle -> particles.forEach { q ->
                val tw = sin((t * 3 + q.d) * PI).toFloat().coerceAtLeast(0f)
                val c = Offset(to.x + (q.a - 0.5f) * unit * 2.6f, to.y + (q.b - 0.5f) * unit * 2.2f)
                val s = unit * (0.15f + q.c * 0.3f) * tw
                drawLine(Color.White, c - Offset(s, 0f), c + Offset(s, 0f), unit * 0.07f)
                drawLine(Color.White, c - Offset(0f, s), c + Offset(0f, s), unit * 0.07f)
                drawCircle(color.copy(alpha = tw), s * 0.4f, c)
            }
            Pattern.Burst -> {
                val r = unit * (0.4f + t * 1.6f)
                repeat(10) { k ->
                    val a = k * PI / 5 + particles[k].a * 0.3
                    val start = Offset(to.x + cos(a).toFloat() * r * 0.4f, to.y + sin(a).toFloat() * r * 0.4f)
                    val end = Offset(to.x + cos(a).toFloat() * r, to.y + sin(a).toFloat() * r)
                    drawLine(Color.White.copy(alpha = 1f - t), start, end, unit * 0.14f, cap = StrokeCap.Round)
                    drawLine(color.copy(alpha = 1f - t), start, end, unit * 0.07f, cap = StrokeCap.Round)
                }
                drawCircle(Color.White.copy(alpha = (1f - t) * 0.8f), unit * 0.5f * (1f - t), to)
            }
        }
    }
}
