import SwiftUI

enum Side { case mine, theirs }

/// Everything the scene needs to draw one Pokémon, animated by the director.
@MainActor
final class MonView: ObservableObject {
    let id: Int
    let name: String
    let maxHp: Int
    let moves: [Move]
    let types: [String]
    let speed: Int

    @Published var hp: Double
    /// Offsets are fractions of the scene width/height.
    @Published var dx: CGFloat = 0
    @Published var dy: CGFloat = 0
    @Published var scale: CGFloat = 0
    @Published var alpha: Double = 1
    @Published var tint: Color = .clear
    @Published var tintAmount: Double = 0
    @Published var visible = false

    init(_ p: BattlePokemon, hp: Int) {
        id = p.pokemonId
        name = p.name.prettyName
        maxHp = p.maxHp
        moves = p.moves ?? []
        types = p.types ?? []
        speed = p.stats?["speed"] ?? 0
        self.hp = Double(hp)
    }
}

/// A Poké Ball flying in an arc towards one side's platform.
struct BallThrow {
    let side: Side
    let start: Date
    let duration: Double
}

struct ActiveEffect {
    let effect: AttackEffect
    let start: Date
    let duration: Double
}

/// Turns the polled battle state into a queue of animated events (intro, turns, faints,
/// switches, end) and plays them one at a time, so new server data never interrupts an
/// animation. The "model" fields track what the screen will show once the queue is done.
/// Port of android/.../ui/battle/BattleDirector.kt.
@MainActor
final class BattleDirector: ObservableObject {
    private enum Event {
        case intro(BattleState)
        case turn(LastTurn, hp1: Int, hp2: Int)
        case faint(Side)
        case nextBattle(BattleState)
        case end(won: Bool, forfeit: Bool)
    }

    private let mySide: String  // "player1" or "player2"
    private let rivalName: @MainActor () -> String
    private let onFinished: @MainActor () -> Void

    private var queue: [Event] = []
    private var running = false

    // MARK: Observable scene state
    @Published private(set) var mine: MonView?
    @Published private(set) var theirs: MonView?
    @Published private(set) var message = ""
    @Published private(set) var visibleChars = 0
    /// Events queued or playing; the move cards are only offered when this is 0.
    @Published private(set) var pending = 0
    var busy: Bool { pending > 0 }
    @Published private(set) var battleNumber = 0
    @Published private(set) var myScore = 0
    @Published private(set) var theirScore = 0
    @Published private(set) var showVs = false
    @Published private(set) var vs: Double = 0
    @Published private(set) var flash: Double = 0
    @Published private(set) var shake: CGFloat = 0
    @Published private(set) var ball: BallThrow?
    @Published private(set) var effect: ActiveEffect?
    @Published private(set) var vsLeads: (mine: Int, theirs: Int)?

    // MARK: Model (state after all queued events)
    private var started = false
    private var ended = false
    private var modelBattle = 0
    private var modelHp1 = 0
    private var modelHp2 = 0
    private var modelScore1 = 0
    private var modelScore2 = 0
    private var seenTurn: String?
    private var effectSeed = 0

    init(mySide: String, rivalName: @escaping @MainActor () -> String, onFinished: @escaping @MainActor () -> Void) {
        self.mySide = mySide
        self.rivalName = rivalName
        self.onFinished = onFinished
    }

    private func sideOf(_ key: String) -> Side { key == mySide ? .mine : .theirs }
    private func view(_ side: Side) -> MonView? { side == .mine ? mine : theirs }

    // MARK: - Feeding

    func onServerState(_ b: BattleState) {
        guard let cp = b.currentPokemon, let hp1 = cp.player1?.hp, let hp2 = cp.player2?.hp else { return }
        let score1 = b.score?.player1 ?? 0
        let score2 = b.score?.player2 ?? 0

        if !started {
            started = true
            enqueue(.intro(b))
            modelBattle = b.battleNumber; modelHp1 = hp1; modelHp2 = hp2
            modelScore1 = score1; modelScore2 = score2
            seenTurn = turnKey(b, b.lastTurn)  // don't replay a turn that happened before we opened the screen
            if b.winner != nil { endMatch(b, score1, score2) }
            return
        }
        if ended { return }

        if let t = b.lastTurn {
            let key = turnKey(b, t)
            if key != seenTurn {
                seenTurn = key
                let turnBattle = t.battleNumber ?? b.battleNumber
                if turnBattle == modelBattle {
                    let h1: Int
                    let h2: Int
                    if b.battleNumber == modelBattle {
                        h1 = hp1; h2 = hp2
                    } else {
                        h1 = max(modelHp1 - (t.damageToPlayer1 ?? 0), 0)
                        h2 = max(modelHp2 - (t.damageToPlayer2 ?? 0), 0)
                    }
                    enqueue(.turn(t, hp1: h1, hp2: h2))
                    modelHp1 = h1; modelHp2 = h2
                }
            }
        }

        if b.battleNumber > modelBattle {
            // The previous fight ended. If we never saw its knockout turn, the score tells who lost.
            if modelHp1 > 0 && modelHp2 > 0 { faintLoser(score1, score2) }
            enqueue(.nextBattle(b))
            modelBattle = b.battleNumber; modelHp1 = hp1; modelHp2 = hp2
        }
        modelScore1 = score1; modelScore2 = score2

        if b.winner != nil { endMatch(b, score1, score2) }
    }

    private func faintLoser(_ score1: Int, _ score2: Int) {
        let p1Won = score1 > modelScore1
        let loserKey = p1Won ? "player2" : "player1"
        enqueue(.faint(sideOf(loserKey)))
        if loserKey == "player1" { modelHp1 = 0 } else { modelHp2 = 0 }
    }

    private func endMatch(_ b: BattleState, _ score1: Int, _ score2: Int) {
        if let forfeitedBy = b.forfeitedBy {
            // Nobody fainted: someone gave up.
            enqueue(.end(won: forfeitedBy != mySide, forfeit: true))
        } else {
            if modelHp1 > 0 && modelHp2 > 0 { faintLoser(score1, score2) }
            let mineScore = mySide == "player1" ? score1 : score2
            let theirScore = mySide == "player1" ? score2 : score1
            enqueue(.end(won: mineScore > theirScore, forfeit: false))
        }
        ended = true
    }

    private func turnKey(_ b: BattleState, _ t: LastTurn?) -> String? {
        guard let t else { return nil }
        if let n = t.turnNumber { return "n\(n)" }
        let cp = b.currentPokemon
        return [
            "\(b.battleNumber)", t.player1Move ?? "", t.player2Move ?? "",
            "\(t.damageToPlayer1 ?? -1)", "\(t.damageToPlayer2 ?? -1)",
            "\(cp?.player1?.hp ?? -1)", "\(cp?.player2?.hp ?? -1)",
        ].joined(separator: "|")
    }

    // MARK: - Playing

    private func enqueue(_ event: Event) {
        queue.append(event)
        pending += 1
        guard !running else { return }
        running = true
        Task { await drain() }
    }

    private func drain() async {
        while !queue.isEmpty {
            let event = queue.removeFirst()
            switch event {
            case .intro(let b): await playIntro(b)
            case .turn(let t, let hp1, let hp2): await playTurn(t, hp1: hp1, hp2: hp2)
            case .faint(let side): if let v = view(side) { await faint(v, side) }
            case .nextBattle(let b): await playNextBattle(b)
            case .end(let won, let forfeit): await playEnd(won: won, forfeit: forfeit)
            }
            pending -= 1
        }
        running = false
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
    }

    /// Animates [changes] and waits for the animation to finish.
    private func animate(_ duration: Double, _ animation: Animation? = nil, _ changes: () -> Void) async {
        withAnimation(animation ?? .easeInOut(duration: duration)) { changes() }
        await sleep(duration)
    }

    private func say(_ text: String, hold: Double = 0.65) async {
        message = text
        visibleChars = 0
        for i in 0..<text.count {
            visibleChars = i + 1
            await sleep(0.022)
        }
        await sleep(hold)
    }

    private func label(_ side: Side, _ name: String) -> String { side == .mine ? name : "\(name) rival" }

    private func sides(of b: BattleState) -> (mine: BattlePokemon, theirs: BattlePokemon)? {
        guard let p1 = b.currentPokemon?.player1, let p2 = b.currentPokemon?.player2 else { return nil }
        return mySide == "player1" ? (p1, p2) : (p2, p1)
    }

    private func playIntro(_ b: BattleState) async {
        guard let pair = sides(of: b) else { return }
        battleNumber = b.battleNumber
        syncScore(b)
        let me = MonView(pair.mine, hp: pair.mine.hp)
        let them = MonView(pair.theirs, hp: pair.theirs.hp)
        mine = me
        theirs = them
        vsLeads = (pair.mine.pokemonId, pair.theirs.pokemonId)

        // VS splash
        showVs = true
        Sound.shared.play(.join)
        vs = 0
        await animate(0.7, .easeOut(duration: 0.7)) { vs = 1 }
        await sleep(1.3)
        flash = 1
        showVs = false
        await animate(0.45, .linear(duration: 0.45)) { flash = 0 }

        await say("¡\(rivalName()) te desafía!", hold: 0.5)
        await sendOut(them, .theirs, "¡\(rivalName()) envió a \(them.name)!")
        await sendOut(me, .mine, "¡Adelante, \(me.name)!")
    }

    private func sendOut(_ v: MonView, _ side: Side, _ text: String) async {
        message = text
        visibleChars = text.count
        ball = BallThrow(side: side, start: Date(), duration: 0.52)
        Sound.shared.play(.throwBall)
        await sleep(0.52)
        ball = nil
        Sound.shared.play(.ballOpen)
        v.alpha = 1
        v.dx = 0
        v.dy = 0
        v.scale = 0
        v.tint = .white
        v.tintAmount = 1
        v.visible = true
        Task {
            await animate(0.08, .linear(duration: 0.08)) { flash = 0.35 }
            await animate(0.25, .linear(duration: 0.25)) { flash = 0 }
        }
        await animate(0.32, .easeOut(duration: 0.32)) { v.scale = 1 }
        withAnimation(.linear(duration: 0.15)) { v.tintAmount = 0 }
        Sound.shared.cry(id: v.id, name: v.name)
        await sleep(0.65)
    }

    private struct Attack {
        let side: Side
        let moveName: String?
        let damage: Int
        let missed: Bool
        let effectiveness: Double?
    }

    private func playTurn(_ t: LastTurn, hp1: Int, hp2: Int) async {
        guard let me = mine, let them = theirs else { return }
        let target: [Side: Int] = [sideOf("player1"): hp1, sideOf("player2"): hp2]
        let p1 = Attack(side: sideOf("player1"), moveName: t.player1Move, damage: t.damageToPlayer2 ?? 0,
                        missed: t.player1Missed == true, effectiveness: t.player1Effectiveness)
        let p2 = Attack(side: sideOf("player2"), moveName: t.player2Move, damage: t.damageToPlayer1 ?? 0,
                        missed: t.player2Missed == true, effectiveness: t.player2Effectiveness)
        let p1First: Bool
        switch t.firstAttacker {
        case "player1": p1First = true
        case "player2": p1First = false
        default: p1First = (view(p1.side)?.speed ?? 0) >= (view(p2.side)?.speed ?? 0)
        }
        var order = p1First ? [p1, p2] : [p2, p1]
        // The current server applies both attacks at once, so a Pokémon knocked out by the faster
        // one still deals damage. Showing it attacking from 0 HP looks wrong, so let it go first.
        if t.firstAttacker == nil && target[order[1].side] == 0 && order[1].damage > 0 {
            order.reverse()
        }

        for a in order {
            guard let attacker = view(a.side) else { continue }
            let defenderSide: Side = a.side == .mine ? .theirs : .mine
            guard let defender = view(defenderSide) else { continue }
            // With the proposed server rules a fainted Pokémon doesn't get to attack.
            if attacker.hp <= 0 && a.damage == 0 { continue }
            let move = attacker.moves.first { $0.name == a.moveName }
            let moveLabel = move.map { MoveNames.shared.name($0) } ?? a.moveName?.prettyName ?? "???"
            await say("¡\(label(a.side, attacker.name)) usó \(moveLabel)!", hold: 0.25)
            await attack(attacker, a.side, move)
            if a.missed {
                Sound.shared.play(.miss)
                await say("¡Pero falló!", hold: 0.5)
                continue
            }
            let eff = a.effectiveness ?? PokeTypes.serverEffectiveness(move?.type, defender.types)
            await hit(defender, target: target[defenderSide] ?? 0, eff: eff)
            if eff > 1 {
                await say("¡Es súper eficaz!", hold: 0.45)
            } else if eff < 1 {
                await say("No es muy eficaz…", hold: 0.45)
            }
        }
        // Keep the bars exact even if the order/rules differ from the server's.
        me.hp = Double(target[.mine] ?? 0)
        them.hp = Double(target[.theirs] ?? 0)
        if them.hp <= 0 { await faint(them, .theirs) }
        if me.hp <= 0 { await faint(me, .mine) }
    }

    private func attack(_ attacker: MonView, _ side: Side, _ move: Move?) async {
        let dir: CGFloat = side == .mine ? 1 : -1
        // Lunge towards the foe.
        await animate(0.11, .linear(duration: 0.11)) {
            attacker.dx = 0.06 * dir
            attacker.dy = -0.04 * dir
        }
        withAnimation(.easeOut(duration: 0.22)) {
            attacker.dx = 0
            attacker.dy = 0
        }
        Sound.shared.play(.card)
        let special = move?.damageClass == "special"
        let duration = special ? 0.95 : 0.7
        effect = ActiveEffect(
            effect: AttackEffect(type: move?.type, special: special, fromSide: side, seed: effectSeed),
            start: Date(),
            duration: duration
        )
        effectSeed += 1
        await sleep(duration)
        effect = nil
    }

    private func hit(_ defender: MonView, target: Int, eff: Double) async {
        Sound.shared.play(eff > 1 ? .superHit : eff < 1 ? .weakHit : .hit)
        Haptics.hit(strong: eff > 1)
        if eff > 1 {
            Task {
                for i in 0..<4 { await animate(0.045, .linear(duration: 0.045)) { shake = i % 2 == 0 ? 1 : -1 } }
                await animate(0.045, .linear(duration: 0.045)) { shake = 0 }
            }
        }
        // Classic blink + shake.
        Task {
            for i in 0..<4 { await animate(0.05, .linear(duration: 0.05)) { defender.dx = i % 2 == 0 ? 0.015 : -0.015 } }
            await animate(0.05, .linear(duration: 0.05)) { defender.dx = 0 }
        }
        for _ in 0..<3 {
            defender.alpha = 0
            await sleep(0.07)
            defender.alpha = 1
            await sleep(0.07)
        }
        // HP drains at a steady DS-like speed.
        let drop = abs(defender.hp - Double(target))
        let duration = min(max(drop * 0.022, 0.25), 1.3)
        await animate(duration, .linear(duration: duration)) { defender.hp = Double(target) }
        await sleep(0.15)
    }

    private func faint(_ v: MonView, _ side: Side) async {
        guard v.visible else { return }
        v.hp = 0
        Sound.shared.cry(id: v.id, name: v.name, pitch: 0.75)
        await sleep(0.3)
        Sound.shared.play(.faint)
        await animate(0.45) {
            v.dy = 0.25
            v.alpha = 0
        }
        v.visible = false
        if side == .mine { theirScore += 1 } else { myScore += 1 }
        await say("¡\(label(side, v.name)) se debilitó!", hold: 0.8)
    }

    private func withdraw(_ v: MonView, _ side: Side) async {
        guard v.visible else { return }
        await say(side == .mine ? "¡\(v.name), vuelve!" : "¡\(rivalName()) retiró a \(v.name)!", hold: 0.25)
        v.tint = Color(hex: 0xFF5050)
        v.tintAmount = 1
        Sound.shared.play(.ballOpen)
        await animate(0.3) { v.scale = 0 }
        v.visible = false
        v.tintAmount = 0
    }

    private func playNextBattle(_ b: BattleState) async {
        if let m = mine { await withdraw(m, .mine) }
        if let t = theirs { await withdraw(t, .theirs) }
        guard let pair = sides(of: b) else { return }
        battleNumber = b.battleNumber
        syncScore(b)
        await say("¡Combate \(b.battleNumber)!", hold: 0.4)
        let them = MonView(pair.theirs, hp: pair.theirs.hp)
        let me = MonView(pair.mine, hp: pair.mine.hp)
        theirs = them
        mine = me
        await sendOut(them, .theirs, "¡\(rivalName()) envió a \(them.name)!")
        await sendOut(me, .mine, "¡Adelante, \(me.name)!")
    }

    private func syncScore(_ b: BattleState) {
        let s1 = b.score?.player1 ?? 0
        let s2 = b.score?.player2 ?? 0
        myScore = mySide == "player1" ? s1 : s2
        theirScore = mySide == "player1" ? s2 : s1
    }

    private func playEnd(won: Bool, forfeit: Bool) async {
        await sleep(0.3)
        if forfeit {
            await say(won ? "¡\(rivalName()) se rindió!" : "¡Te rendiste!", hold: 0.3)
        }
        Sound.shared.play(won ? .victory : .defeat)
        await say(won ? "¡Derrotaste a \(rivalName())!" : "¡\(rivalName()) te ha derrotado!", hold: 1.6)
        onFinished()
    }
}
