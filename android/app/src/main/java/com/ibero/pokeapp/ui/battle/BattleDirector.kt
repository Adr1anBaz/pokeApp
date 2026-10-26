package com.ibero.pokeapp.ui.battle

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.ibero.pokeapp.audio.Sfx
import com.ibero.pokeapp.audio.Sound
import com.ibero.pokeapp.data.BattlePokemon
import com.ibero.pokeapp.data.BattleState
import com.ibero.pokeapp.data.LastTurn
import com.ibero.pokeapp.data.Move
import com.ibero.pokeapp.data.MoveNames
import com.ibero.pokeapp.data.prettyName
import com.ibero.pokeapp.ui.theme.PokeTypes
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt

enum class Side { Mine, Theirs }

/** Everything the scene needs to draw one Pokémon, animated by the director. */
class MonView(p: BattlePokemon, hp: Int) {
    val id = p.pokemonId
    val name = p.name.prettyName()
    val maxHp = p.maxHp
    val moves: List<Move> = p.moves.orEmpty()
    val types = p.types.orEmpty()
    val speed = p.stats?.get("speed") ?: 0

    val hp = Animatable(hp.toFloat())
    /** Offsets are fractions of the scene width/height. */
    val dx = Animatable(0f)
    val dy = Animatable(0f)
    val scale = Animatable(0f)
    val alpha = Animatable(1f)
    var tint by mutableStateOf(Color.Transparent)
    var visible by mutableStateOf(false)
}

/** A Poké Ball flying in an arc towards one side's platform. */
class BallThrow(val side: Side) {
    val progress = Animatable(0f)
}

class ActiveEffect(val effect: AttackEffect) {
    val progress = Animatable(0f)
}

/**
 * Turns the polled battle state into a queue of animated events (intro, turns, faints,
 * switches, end) and plays them one at a time, so new server data never interrupts an
 * animation. The "model" fields track what the screen will show once the queue is done.
 */
class BattleDirector(
    private val mySide: String,          // "player1" or "player2"
    private val rivalName: () -> String,
    private val onHit: (strong: Boolean) -> Unit,
    private val onFinished: () -> Unit,
) {
    private sealed interface Event {
        data class Intro(val state: BattleState) : Event
        data class Turn(val turn: LastTurn, val hp1: Int, val hp2: Int) : Event
        data class Faint(val side: Side) : Event
        data class NextBattle(val state: BattleState) : Event
        data class End(val won: Boolean, val forfeit: Boolean) : Event
    }

    private val queue = Channel<Event>(Channel.UNLIMITED)

    // ---------- Observable scene state ----------
    var mine by mutableStateOf<MonView?>(null)
        private set
    var theirs by mutableStateOf<MonView?>(null)
        private set
    var message by mutableStateOf("")
        private set
    var visibleChars by mutableIntStateOf(0)
        private set
    /** Events queued or playing; the move cards are only offered when this is 0. */
    private var pending by mutableIntStateOf(0)
    val busy: Boolean get() = pending > 0
    var battleNumber by mutableIntStateOf(0)
        private set
    var myScore by mutableIntStateOf(0)
        private set
    var theirScore by mutableIntStateOf(0)
        private set
    var showVs by mutableStateOf(false)
        private set
    val vs = Animatable(0f)
    val flash = Animatable(0f)
    val shake = Animatable(0f)
    var ball by mutableStateOf<BallThrow?>(null)
        private set
    var effect by mutableStateOf<ActiveEffect?>(null)
        private set
    var vsLeads by mutableStateOf<Pair<Int, Int>?>(null)
        private set

    // ---------- Model (state after all queued events) ----------
    private var started = false
    private var ended = false
    private var modelBattle = 0
    private var modelHp1 = 0
    private var modelHp2 = 0
    private var modelScore1 = 0
    private var modelScore2 = 0
    private var seenTurn: String? = null
    private var effectSeed = 0

    private fun sideOf(key: String) = if (key == mySide) Side.Mine else Side.Theirs
    private fun view(side: Side) = if (side == Side.Mine) mine else theirs

    // ---------- Feeding ----------

    fun onServerState(b: BattleState) {
        val cp = b.currentPokemon ?: return
        val hp1 = cp.player1?.hp ?: return
        val hp2 = cp.player2?.hp ?: return
        val score1 = b.score?.player1 ?: 0
        val score2 = b.score?.player2 ?: 0

        if (!started) {
            started = true
            enqueue(Event.Intro(b))
            modelBattle = b.battleNumber; modelHp1 = hp1; modelHp2 = hp2
            modelScore1 = score1; modelScore2 = score2
            seenTurn = turnKey(b, b.lastTurn)  // don't replay a turn that happened before we opened the screen
            if (b.winner != null) endMatch(b, score1, score2)
            return
        }
        if (ended) return

        val t = b.lastTurn
        val key = turnKey(b, t)
        if (t != null && key != seenTurn) {
            seenTurn = key
            val turnBattle = t.battleNumber ?: b.battleNumber
            if (turnBattle == modelBattle) {
                val (h1, h2) = if (b.battleNumber == modelBattle) {
                    hp1 to hp2
                } else {
                    (modelHp1 - (t.damageToPlayer1 ?: 0)).coerceAtLeast(0) to (modelHp2 - (t.damageToPlayer2 ?: 0)).coerceAtLeast(0)
                }
                enqueue(Event.Turn(t, h1, h2))
                modelHp1 = h1; modelHp2 = h2
            }
        }

        if (b.battleNumber > modelBattle) {
            // The previous fight ended. If we never saw its knockout turn, the score tells who lost.
            if (modelHp1 > 0 && modelHp2 > 0) faintLoser(score1, score2)
            enqueue(Event.NextBattle(b))
            modelBattle = b.battleNumber; modelHp1 = hp1; modelHp2 = hp2
        }
        modelScore1 = score1; modelScore2 = score2

        if (b.winner != null) endMatch(b, score1, score2)
    }

    private fun faintLoser(score1: Int, score2: Int) {
        val p1Won = score1 > modelScore1
        val loserKey = if (p1Won) "player2" else "player1"
        enqueue(Event.Faint(sideOf(loserKey)))
        if (loserKey == "player1") modelHp1 = 0 else modelHp2 = 0
    }

    private fun endMatch(b: BattleState, score1: Int, score2: Int) {
        val forfeitedBy = b.forfeitedBy
        if (forfeitedBy != null) {
            // Nobody fainted: someone gave up.
            enqueue(Event.End(won = forfeitedBy != mySide, forfeit = true))
        } else {
            if (modelHp1 > 0 && modelHp2 > 0) faintLoser(score1, score2)
            val mineScore = if (mySide == "player1") score1 else score2
            val theirScore = if (mySide == "player1") score2 else score1
            enqueue(Event.End(mineScore > theirScore, forfeit = false))
        }
        ended = true
    }

    private fun turnKey(b: BattleState, t: LastTurn?): String? {
        if (t == null) return null
        t.turnNumber?.let { return "n$it" }
        val cp = b.currentPokemon
        return listOf(b.battleNumber, t.player1Move, t.player2Move, t.damageToPlayer1, t.damageToPlayer2, cp?.player1?.hp, cp?.player2?.hp)
            .joinToString("|")
    }

    // ---------- Playing ----------

    suspend fun run() {
        for (event in queue) {
            when (event) {
                is Event.Intro -> playIntro(event.state)
                is Event.Turn -> playTurn(event)
                is Event.Faint -> view(event.side)?.let { faint(it, event.side) }
                is Event.NextBattle -> playNextBattle(event.state)
                is Event.End -> playEnd(event.won, event.forfeit)
            }
            pending--
        }
    }

    private fun enqueue(event: Event) {
        pending++
        queue.trySend(event)
    }

    private suspend fun say(text: String, hold: Long = 650) {
        message = text
        visibleChars = 0
        for (i in 1..text.length) {
            visibleChars = i
            delay(22)
        }
        delay(hold)
    }

    private fun label(side: Side, name: String) = if (side == Side.Mine) name else "$name rival"

    private suspend fun playIntro(b: BattleState) {
        val cp = b.currentPokemon!!
        val mineP = if (mySide == "player1") cp.player1!! else cp.player2!!
        val theirP = if (mySide == "player1") cp.player2!! else cp.player1!!
        battleNumber = b.battleNumber
        syncScore(b)
        mine = MonView(mineP, mineP.hp)
        theirs = MonView(theirP, theirP.hp)
        vsLeads = mineP.pokemonId to theirP.pokemonId

        // VS splash
        showVs = true
        Sound.play(Sfx.Join)
        vs.snapTo(0f)
        vs.animateTo(1f, tween(700, easing = FastOutSlowInEasing))
        delay(1300)
        flash.snapTo(1f)
        showVs = false
        flash.animateTo(0f, tween(450))

        say("¡${rivalName()} te desafía!", 500)
        sendOut(theirs!!, Side.Theirs, "¡${rivalName()} envió a ${theirs!!.name}!")
        sendOut(mine!!, Side.Mine, "¡Adelante, ${mine!!.name}!")
    }

    private suspend fun sendOut(v: MonView, side: Side, text: String) = coroutineScope {
        message = text
        visibleChars = text.length
        val throwBall = BallThrow(side)
        ball = throwBall
        Sound.play(Sfx.Throw)
        throwBall.progress.animateTo(1f, tween(520, easing = LinearEasing))
        ball = null
        Sound.play(Sfx.BallOpen)
        v.visible = true
        v.tint = Color.White
        v.alpha.snapTo(1f)
        v.dx.snapTo(0f); v.dy.snapTo(0f)
        launch { flash.animateTo(0.35f, tween(80)); flash.animateTo(0f, tween(250)) }
        v.scale.snapTo(0f)
        v.scale.animateTo(1f, tween(320, easing = FastOutSlowInEasing))
        v.tint = Color.Transparent
        Sound.cry(v.id)
        delay(650)
    }

    private data class Attack(val side: Side, val moveName: String?, val damage: Int, val missed: Boolean, val effectiveness: Double?)

    private suspend fun playTurn(e: Event.Turn) {
        val t = e.turn
        val me = mine ?: return
        val them = theirs ?: return
        val targetHp = mapOf(
            sideOf("player1") to e.hp1,
            sideOf("player2") to e.hp2,
        )
        val p1 = Attack(sideOf("player1"), t.player1Move, t.damageToPlayer2 ?: 0, t.player1Missed == true, t.player1Effectiveness)
        val p2 = Attack(sideOf("player2"), t.player2Move, t.damageToPlayer1 ?: 0, t.player2Missed == true, t.player2Effectiveness)
        val p1View = view(p1.side)!!
        val p2View = view(p2.side)!!
        val p1First = when (t.firstAttacker) {
            "player1" -> true
            "player2" -> false
            else -> p1View.speed >= p2View.speed
        }
        var order = if (p1First) listOf(p1, p2) else listOf(p2, p1)
        // The current server applies both attacks at once, so a Pokémon knocked out by the faster
        // one still deals damage. Showing it attacking from 0 HP looks wrong, so let it go first.
        if (t.firstAttacker == null && targetHp.getValue(order[1].side) == 0 && order[1].damage > 0) {
            order = order.reversed()
        }

        for (a in order) {
            val attacker = view(a.side)!!
            val defenderSide = if (a.side == Side.Mine) Side.Theirs else Side.Mine
            val defender = view(defenderSide)!!
            // With the proposed server rules a fainted Pokémon doesn't get to attack.
            if (attacker.hp.value <= 0f && a.damage == 0) continue
            val move = attacker.moves.find { it.name == a.moveName }
            val moveLabel = move?.let { MoveNames.name(it) } ?: a.moveName?.prettyName() ?: "???"
            say("¡${label(a.side, attacker.name)} usó $moveLabel!", 250)
            attack(attacker, a.side, move)
            if (a.missed) {
                Sound.play(Sfx.Miss)
                say("¡Pero falló!", 500)
                continue
            }
            val eff = a.effectiveness ?: PokeTypes.serverEffectiveness(move?.type, defender.types)
            hit(defender, defenderSide, targetHp.getValue(defenderSide), eff)
            when {
                eff > 1.0 -> say("¡Es súper eficaz!", 450)
                eff < 1.0 -> say("No es muy eficaz…", 450)
            }
        }
        // Keep the bars exact even if the order/rules differ from the server's.
        me.hp.snapTo(targetHp.getValue(Side.Mine).toFloat())
        them.hp.snapTo(targetHp.getValue(Side.Theirs).toFloat())
        if (them.hp.value <= 0f) faint(them, Side.Theirs)
        if (me.hp.value <= 0f) faint(me, Side.Mine)
    }

    private suspend fun attack(attacker: MonView, side: Side, move: Move?) = coroutineScope {
        val dir = if (side == Side.Mine) 1f else -1f
        // Lunge towards the foe.
        attacker.dx.animateTo(0.06f * dir, tween(110))
        attacker.dy.animateTo(-0.04f * dir, tween(110))
        launch { attacker.dx.animateTo(0f, tween(220)) }
        launch { attacker.dy.animateTo(0f, tween(220)) }
        Sound.play(Sfx.Card)
        val fx = ActiveEffect(
            AttackEffect(move?.type, move?.damageClass == "special", from = Anchors.center(side), to = Anchors.center(if (side == Side.Mine) Side.Theirs else Side.Mine), seed = effectSeed++)
        )
        effect = fx
        fx.progress.animateTo(1f, tween(if (move?.damageClass == "special") 950 else 700, easing = LinearEasing))
        effect = null
    }

    private suspend fun hit(defender: MonView, side: Side, target: Int, eff: Double) = coroutineScope {
        Sound.play(
            when {
                eff > 1.0 -> Sfx.SuperHit
                eff < 1.0 -> Sfx.WeakHit
                else -> Sfx.Hit
            }
        )
        onHit(eff > 1.0)
        if (eff > 1.0) launch { repeat(4) { shake.animateTo(if (it % 2 == 0) 1f else -1f, tween(45)) }; shake.animateTo(0f, tween(45)) }
        // Classic blink + shake.
        launch { repeat(4) { defender.dx.animateTo(if (it % 2 == 0) 0.015f else -0.015f, tween(50)) }; defender.dx.animateTo(0f, tween(50)) }
        repeat(3) {
            defender.alpha.snapTo(0f); delay(70)
            defender.alpha.snapTo(1f); delay(70)
        }
        // HP drains at a steady DS-like speed.
        val drop = abs(defender.hp.value - target)
        defender.hp.animateTo(target.toFloat(), tween((drop * 22).roundToInt().coerceIn(250, 1300), easing = LinearEasing))
        delay(150)
    }

    private suspend fun faint(v: MonView, side: Side) {
        if (!v.visible) return
        v.hp.snapTo(0f)
        Sound.cry(v.id, pitch = 0.75f)
        delay(300)
        Sound.play(Sfx.Faint)
        coroutineScope {
            launch { v.dy.animateTo(0.25f, tween(450, easing = FastOutSlowInEasing)) }
            v.alpha.animateTo(0f, tween(450))
        }
        v.visible = false
        if (side == Side.Mine) theirScore++ else myScore++
        say("¡${label(side, v.name)} se debilitó!", 800)
    }

    private suspend fun withdraw(v: MonView, side: Side) {
        if (!v.visible) return
        say(if (side == Side.Mine) "¡${v.name}, vuelve!" else "¡${rivalName()} retiró a ${v.name}!", 250)
        v.tint = Color(0xFFFF5050)
        Sound.play(Sfx.BallOpen)
        v.scale.animateTo(0f, tween(300))
        v.visible = false
        v.tint = Color.Transparent
    }

    private suspend fun playNextBattle(b: BattleState) {
        mine?.let { withdraw(it, Side.Mine) }
        theirs?.let { withdraw(it, Side.Theirs) }
        val cp = b.currentPokemon!!
        val mineP = if (mySide == "player1") cp.player1!! else cp.player2!!
        val theirP = if (mySide == "player1") cp.player2!! else cp.player1!!
        battleNumber = b.battleNumber
        syncScore(b)
        say("¡Combate ${b.battleNumber}!", 400)
        theirs = MonView(theirP, theirP.hp)
        mine = MonView(mineP, mineP.hp)
        sendOut(theirs!!, Side.Theirs, "¡${rivalName()} envió a ${theirs!!.name}!")
        sendOut(mine!!, Side.Mine, "¡Adelante, ${mine!!.name}!")
    }

    private fun syncScore(b: BattleState) {
        val s1 = b.score?.player1 ?: 0
        val s2 = b.score?.player2 ?: 0
        myScore = if (mySide == "player1") s1 else s2
        theirScore = if (mySide == "player1") s2 else s1
    }

    private suspend fun playEnd(won: Boolean, forfeit: Boolean) {
        delay(300)
        if (forfeit) {
            say(if (won) "¡${rivalName()} se rindió!" else "¡Te rendiste!", 300)
        }
        if (won) {
            Sound.play(Sfx.Victory)
            say("¡Derrotaste a ${rivalName()}!", 1600)
        } else {
            Sound.play(Sfx.Defeat)
            say("¡${rivalName()} te ha derrotado!", 1600)
        }
        onFinished()
    }
}

/** Where things sit in the scene, as fractions of its width/height. */
object Anchors {
    // Bottom-center of each sprite (where it stands on its platform).
    const val THEIR_X = 0.70f
    const val THEIR_Y = 0.52f
    const val MY_X = 0.27f
    const val MY_Y = 0.99f

    /** Set by the scene once it knows its size in pixels. */
    var width = 1f
    var height = 1f

    fun center(side: Side) = if (side == Side.Mine) {
        androidx.compose.ui.geometry.Offset(MY_X * width, (MY_Y - 0.2f) * height)
    } else {
        androidx.compose.ui.geometry.Offset(THEIR_X * width, (THEIR_Y - 0.13f) * height)
    }
}
