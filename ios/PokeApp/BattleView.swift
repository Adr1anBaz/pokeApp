import SwiftUI

/// Port of android/.../ui/battle/BattleScreen.kt.
struct BattleView: View {
    @ObservedObject var vm: GameViewModel
    @StateObject private var director: BattleDirector
    @State private var confirmForfeit = false

    init(vm: GameViewModel) {
        _vm = ObservedObject(wrappedValue: vm)
        _director = StateObject(wrappedValue: BattleDirector(
            mySide: vm.myKey,
            rivalName: { [weak vm] in vm?.opponent?.name ?? "Rival" },
            onFinished: { [weak vm] in vm?.showResult() }
        ))
    }

    var body: some View {
        ZStack {
            Ds.ink
            VStack(spacing: 0) {
                BattleTopBar(vm: vm, director: director)
                BattleScene(director: director)
                MessageBox(vm: vm, director: director)
                ErrorBanner(message: vm.error)
                    .padding(.horizontal, 10)
                CardHand(vm: vm, director: director) { confirmForfeit = true }
                    .frame(maxHeight: .infinity)
            }
            if director.showVs { VsOverlay(vm: vm, director: director) }
            Color.white
                .opacity(director.flash)
                .allowsHitTesting(false)
            if vm.battle == nil {
                VStack(spacing: 8) {
                    SpinningPokeball(size: 56)
                    Text("Preparando batalla…")
                        .font(PixelFont.titleLarge)
                        .foregroundColor(.white)
                }
            }
            if confirmForfeit {
                ForfeitDialog(
                    rival: vm.opponent?.name ?? "tu rival",
                    loading: vm.loading,
                    onConfirm: { vm.forfeit() },
                    onDismiss: { confirmForfeit = false }
                )
            }
        }
        .onAppear {
            if let b = vm.battle { director.onServerState(b) }
        }
        .onChange(of: vm.battle) { b in
            if let b { director.onServerState(b) }
            if b?.winner != nil { confirmForfeit = false }
        }
    }
}

// MARK: - Top bar

private struct BattleTopBar: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject var director: BattleDirector
    @ObservedObject private var sound = Sound.shared

    var body: some View {
        HStack(spacing: 0) {
            PartyBalls(fainted: director.theirScore)
            Text(" \(vm.playerName)")
                .font(PixelFont.labelMedium)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(director.battleNumber > 0 ? "COMBATE \(director.battleNumber)/3" : "")
                .font(PixelFont.title(11))
                .foregroundColor(Ds.yellow)
                .fixedSize()
            Text("\(vm.opponent?.name ?? "Rival") ")
                .font(PixelFont.labelMedium)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            PartyBalls(fainted: director.myScore)
            Button(sound.muted ? " 🔇" : " 🔊") { sound.toggleMute() }
                .font(.system(size: 18))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(LinearGradient(colors: [Color(hex: 0x384048), Ds.ink], startPoint: .top, endPoint: .bottom))
    }
}

/// The 3 Poké Balls of a party; fainted ones are greyed out.
struct PartyBalls: View {
    let fainted: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { Pokeball(size: 14, greyed: $0 < fainted) }
        }
    }
}

// MARK: - Scene

private struct BattleScene: View {
    @ObservedObject var director: BattleDirector

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                TimelineView(.animation) { context in
                    Canvas { g, canvasSize in
                        let drift = CGFloat(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5)
                        drawBackdrop(g, canvasSize, drift: drift)
                    }
                }

                // Showdown back sprites are drawn bigger than the front ones, so yours gets a smaller factor.
                if let them = director.theirs {
                    MonSprite(mon: them, side: .theirs, scene: size, scale: size.width / 215)
                }
                if let me = director.mine {
                    MonSprite(mon: me, side: .mine, scene: size, scale: size.width / 270)
                }

                TimelineView(.animation) { context in
                    Canvas { g, canvasSize in
                        if let ball = director.ball {
                            let t = CGFloat(min(context.date.timeIntervalSince(ball.start) / ball.duration, 1))
                            drawThrownBall(g, canvasSize, side: ball.side, t: t)
                        }
                        if let fx = director.effect {
                            let p = CGFloat(min(context.date.timeIntervalSince(fx.start) / fx.duration, 1))
                            fx.effect.draw(g, size: canvasSize, progress: p)
                        }
                    }
                }
                .allowsHitTesting(false)

                if let them = director.theirs {
                    HpBox(mon: them, side: .theirs, fainted: director.myScore)
                        .frame(width: size.width * 0.56)
                        .offset(x: 8, y: 10)
                        .id(ObjectIdentifier(them))
                }
                if let me = director.mine {
                    HpBox(mon: me, side: .mine, fainted: director.theirScore)
                        .frame(width: size.width * 0.54)
                        .offset(x: size.width * 0.46 - 8, y: size.height * 0.60)
                        .id(ObjectIdentifier(me))
                }
            }
        }
        .aspectRatio(1.15, contentMode: .fit)
        .offset(x: director.shake * 10)
        .clipped()
    }
}

/// A Pokémon standing on its platform: bottom-center of the sprite at the side's anchor.
private struct MonSprite: View {
    @ObservedObject var mon: MonView
    let side: Side
    let scene: CGSize
    let scale: CGFloat

    var body: some View {
        if mon.visible {
            let mine = side == .mine
            TimelineView(.animation) { context in
                // Gentle idle bob, like the DS games.
                let period = mine ? 1.8 : 2.2
                let bob = (sin(context.date.timeIntervalSinceReferenceDate / period * 2 * Double.pi) + 1) / 2
                PixelSprite(
                    url: mine ? Sprites.animatedBack(mon.id) : Sprites.animatedFront(mon.id),
                    fallbackURL: mine ? Sprites.back(mon.id) : Sprites.front(mon.id),
                    scale: scale,
                    tint: mon.tint,
                    tintAmount: mon.tintAmount
                )
                .offset(y: -CGFloat(bob) * 3)
            }
            .scaleEffect(max(mon.scale, 0.001), anchor: .bottom)
            .frame(width: scene.width, height: scene.height, alignment: .bottom)
            .position(
                x: (mine ? Anchors.myX : Anchors.theirX) * scene.width,
                y: (mine ? Anchors.myY : Anchors.theirY) * scene.height - scene.height / 2
            )
            .offset(x: mon.dx * scene.width, y: mon.dy * scene.height)
            .opacity(mon.alpha)
        }
    }
}

private func drawBackdrop(_ g: GraphicsContext, _ size: CGSize, drift: CGFloat) {
    let w = size.width
    let h = size.height
    let horizon = h * 0.56
    g.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)),
           with: .linearGradient(Gradient(colors: [Ds.skyTop, Ds.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
    // Speed lines drifting across the sky.
    let lines: [(CGFloat, CGFloat)] = [(0.08, 0.5), (0.17, 0.3), (0.27, 0.6), (0.36, 0.25), (0.45, 0.45)]
    for (i, entry) in lines.enumerated() {
        let x = (drift + CGFloat(i) * 0.37).truncatingRemainder(dividingBy: 1) * (w * 1.6) - w * 0.6
        g.fill(Path(roundedRect: CGRect(x: x, y: h * entry.0, width: w * entry.1, height: h * 0.022), cornerRadius: h * 0.011),
               with: .color(Color.white.opacity(0.45)))
    }
    g.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
           with: .linearGradient(Gradient(colors: [Color(hex: 0xA8E080), Color(hex: 0x70B850)]),
                                 startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
    for k in 0..<6 {
        let y = horizon + (h - horizon) * CGFloat(k) / 6
        g.fill(Path(CGRect(x: 0, y: y, width: w, height: (h - horizon) / 12)), with: .color(Color.white.opacity(0.06)))
    }
    drawPlatform(g, center: CGPoint(x: Anchors.theirX * w, y: Anchors.theirY * h - h * 0.01), size: CGSize(width: w * 0.48, height: h * 0.11))
    drawPlatform(g, center: CGPoint(x: Anchors.myX * w, y: Anchors.myY * h - h * 0.02), size: CGSize(width: w * 0.64, height: h * 0.14))
}

private func drawPlatform(_ g: GraphicsContext, center: CGPoint, size s: CGSize) {
    let origin = CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2)
    g.fill(Path(ellipseIn: CGRect(x: origin.x, y: origin.y + s.height * 0.12, width: s.width, height: s.height)), with: .color(Ds.grassDark))
    g.fill(Path(ellipseIn: CGRect(origin: origin, size: s)), with: .color(Ds.grass))
    g.fill(Path(ellipseIn: CGRect(x: origin.x + s.width * 0.12, y: origin.y + s.height * 0.12, width: s.width * 0.76, height: s.height * 0.6)),
           with: .color(Color(hex: 0xA0E070)))
    // Grass tufts around the rim.
    for k in 0..<9 {
        let a = Double.pi * (0.05 + 0.9 * Double(k) / 8)
        let x = center.x - CGFloat(cos(a)) * s.width * 0.47
        let y = center.y - CGFloat(sin(a)) * s.height * 0.42
        var tuft = Path()
        tuft.move(to: CGPoint(x: x - s.height * 0.12, y: y))
        tuft.addLine(to: CGPoint(x: x, y: y - s.height * 0.3))
        tuft.addLine(to: CGPoint(x: x + s.height * 0.12, y: y))
        tuft.closeSubpath()
        g.fill(tuft, with: .color(Ds.grassDark))
    }
}

private func drawThrownBall(_ g: GraphicsContext, _ size: CGSize, side: Side, t: CGFloat) {
    let w = size.width
    let h = size.height
    let start = side == .mine ? CGPoint(x: -0.05 * w, y: 0.9 * h) : CGPoint(x: 1.05 * w, y: 0.05 * h)
    let end = side == .mine
        ? CGPoint(x: Anchors.myX * w, y: (Anchors.myY - 0.15) * h)
        : CGPoint(x: Anchors.theirX * w, y: (Anchors.theirY - 0.1) * h)
    let pos = CGPoint(x: start.x + (end.x - start.x) * t,
                      y: start.y + (end.y - start.y) * t - sin(t * .pi) * h * 0.3)
    var ball = g
    ball.translateBy(x: pos.x, y: pos.y)
    ball.rotate(by: .degrees(Double(t) * 720))
    Pokeball.draw(in: ball, center: .zero, radius: w * 0.035)
}

/// HP bar and numbers interpolated together while the director animates [hp].
private struct HpReadout: View, Animatable {
    var hp: Double
    let maxHp: Int
    let showNumbers: Bool

    var animatableData: Double {
        get { hp }
        set { hp = newValue }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Text("PS")
                    .font(PixelFont.labelSmall.bold())
                    .foregroundColor(Ds.yellow)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Ds.ink))
                HpBar(hp: hp, maxHp: maxHp)
            }
            if showNumbers {
                Text("\(Int(hp.rounded())) / \(maxHp)")
                    .font(PixelFont.titleSmall)
                    .foregroundColor(Ds.ink)
            }
        }
    }
}

/// DS-style status box: name, party, HP bar (and numbers for your own Pokémon).
private struct HpBox: View {
    @ObservedObject var mon: MonView
    let side: Side
    let fainted: Int
    @State private var shown = false

    var body: some View {
        let mine = side == .mine
        let shape = UnevenCorners(big: 14, small: 4, bigOnLeft: mine)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(mon.name)
                    .font(PixelFont.titleSmall)
                    .foregroundColor(Ds.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(mon.types.prefix(2)), id: \.self) { type in
                    Circle()
                        .fill(PokeTypes.style(type).color)
                        .overlay(Circle().strokeBorder(Ds.ink, lineWidth: 1))
                        .frame(width: 10, height: 10)
                }
            }
            HpReadout(hp: mon.hp, maxHp: mon.maxHp, showNumbers: mine)
            if !mine {
                PartyBalls(fainted: fainted).padding(.top, 3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(shape.fill(LinearGradient(colors: [Color(hex: 0xF8F8E8), Color(hex: 0xE0E0C8)], startPoint: .top, endPoint: .bottom)))
        .padding(3)
        .background(shape.fill(Ds.frame))
        .offset(x: shown ? 0 : (mine ? 500 : -500))
        .opacity(shown ? 1 : 0)
        .onAppear { if mon.visible { reveal() } }
        .onChange(of: mon.visible) { visible in if visible { reveal() } }
    }

    private func reveal() {
        guard !shown else { return }
        withAnimation(.easeOut(duration: 0.35)) { shown = true }
    }
}

/// Rounded rectangle with one big corner (top-left for yours, top-right for the rival's).
private struct UnevenCorners: Shape {
    let big: CGFloat
    let small: CGFloat
    let bigOnLeft: Bool

    func path(in rect: CGRect) -> Path {
        let tl = bigOnLeft ? big : small
        let tr = bigOnLeft ? small : big
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - small))
        p.addArc(center: CGPoint(x: rect.maxX - small, y: rect.maxY - small), radius: small, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + small, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + small, y: rect.maxY - small), radius: small, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Dialog

private struct MessageBox: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject var director: BattleDirector

    var body: some View {
        let b = vm.battle
        let text: String = {
            if director.busy { return String(director.message.prefix(director.visibleChars)) }
            if b?.winner != nil { return director.message }
            if vm.waitingForOpponent { return "Esperando a \(vm.opponent?.name ?? "tu rival")…" }
            if b?.status == "finished" { return "Preparando el siguiente combate…" }
            if let me = director.mine { return "¿Qué hará \(me.name)?" }
            return ""
        }()
        DsPanel(accent: Ds.red, padding: 10) {
            ZStack(alignment: .bottomTrailing) {
                Text(text)
                    .font(PixelFont.titleLarge)
                    .foregroundColor(Ds.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if director.busy && director.visibleChars >= director.message.count {
                    TimelineView(.animation) { context in
                        let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2 * Double.pi) + 1) / 2
                        Text("▼")
                            .font(.system(size: 14))
                            .foregroundColor(Ds.red)
                            .offset(y: CGFloat(phase) * 4)
                    }
                }
                if !director.busy && vm.waitingForOpponent {
                    SpinningPokeball(size: 22)
                }
            }
        }
        .frame(height: 92)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

// MARK: - Forfeit

private struct ForfeitDialog: View {
    let rival: String
    let loading: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { if !loading { onDismiss() } }
            DsPanel(accent: Ds.red) {
                VStack(spacing: 12) {
                    Text("¿RENDIRTE?")
                        .font(PixelFont.headlineMedium)
                        .foregroundColor(Ds.red)
                    Text("Perderás la partida y \(rival) será el ganador.")
                        .font(PixelFont.bodyLarge)
                        .foregroundColor(Ds.ink)
                        .multilineTextAlignment(.center)
                    PixelButton(text: loading ? "RINDIÉNDOSE…" : "SÍ, RENDIRME", enabled: !loading, action: onConfirm)
                    PixelButton(text: "SEGUIR PELEANDO", color: Ds.blue, dark: Ds.blueDark, enabled: !loading, action: onDismiss)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - VS splash

private struct VsOverlay: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject var director: BattleDirector

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p = CGFloat(director.vs)
            ZStack {
                Canvas { g, size in
                    var top = Path()
                    top.move(to: .zero)
                    top.addLine(to: CGPoint(x: size.width, y: 0))
                    top.addLine(to: CGPoint(x: size.width, y: size.height * 0.42))
                    top.addLine(to: CGPoint(x: 0, y: size.height * 0.58))
                    top.closeSubpath()
                    var bottom = Path()
                    bottom.move(to: CGPoint(x: 0, y: size.height * 0.58))
                    bottom.addLine(to: CGPoint(x: size.width, y: size.height * 0.42))
                    bottom.addLine(to: CGPoint(x: size.width, y: size.height))
                    bottom.addLine(to: CGPoint(x: 0, y: size.height))
                    bottom.closeSubpath()
                    g.fill(top, with: .linearGradient(Gradient(colors: [Ds.blue, Ds.blueDark]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.58)))
                    g.fill(bottom, with: .linearGradient(Gradient(colors: [Ds.redDark, Ds.red]), startPoint: CGPoint(x: 0, y: size.height * 0.42), endPoint: CGPoint(x: 0, y: size.height)))
                    var divider = Path()
                    divider.move(to: CGPoint(x: 0, y: size.height * 0.58))
                    divider.addLine(to: CGPoint(x: size.width, y: size.height * 0.42))
                    g.stroke(divider, with: .color(.white), lineWidth: 8)
                }
                // Rival comes in from the right (top half), you from the left (bottom half).
                VStack(alignment: .trailing, spacing: 4) {
                    if let leads = director.vsLeads {
                        RemoteImage(url: Sprites.artwork(leads.theirs)).frame(width: 170, height: 170)
                    }
                    OutlinedText(text: vm.opponent?.name ?? "Rival", font: PixelFont.headlineMedium, fill: .white, outline: Ds.blueDark)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 70)
                .padding(.trailing, 20)
                .offset(x: (1 - p) * w)

                VStack(alignment: .leading, spacing: 4) {
                    OutlinedText(text: vm.playerName, font: PixelFont.headlineMedium, fill: .white, outline: Ds.redDark)
                    if let leads = director.vsLeads {
                        RemoteImage(url: Sprites.artwork(leads.mine)).frame(width: 170, height: 170)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 70)
                .padding(.leading, 20)
                .offset(x: (p - 1) * w)

                OutlinedText(text: "VS", font: PixelFont.title(64), width: 4.5)
                    .scaleEffect(max(p * 1.1, 0.01))
                    .rotationEffect(.degrees(Double(1 - p) * -40))
            }
        }
        .ignoresSafeArea()
    }
}
