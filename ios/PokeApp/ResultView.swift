import SwiftUI

/// Port of android/.../ui/ResultScreen.kt.
struct ResultView: View {
    @ObservedObject var vm: GameViewModel
    @State private var popped = false

    var body: some View {
        let b = vm.battle
        let won = vm.iWon(b)
        StripedBackground(
            top: won ? Color(hex: 0xF8B820) : Color(hex: 0x384058),
            bottom: won ? Color(hex: 0xF87830) : Color(hex: 0x586078)
        ) {
            ZStack {
                if won { Confetti() }
                ScrollView {
                    VStack(spacing: 18) {
                        Text(won ? "🏆" : "💫")
                            .font(.system(size: 84))
                            .scaleEffect(popped ? 1 : 0.01)
                        OutlinedText(
                            text: won ? "¡VICTORIA!" : "DERROTA",
                            font: PixelFont.display,
                            fill: won ? Ds.yellow : .white,
                            outline: won ? Ds.redDark : Ds.ink,
                            width: 3.5
                        )
                        .scaleEffect(popped ? 1 : 0.01)
                        DsPanel(accent: won ? Ds.yellow : Ds.frame) {
                            VStack(spacing: 4) {
                                Text("Ganador: \(b?.winner ?? "?")")
                                    .font(PixelFont.titleLarge)
                                    .foregroundColor(Ds.ink)
                                Text("\(vm.playerName)  \(vm.myScore(b)) - \(vm.opponentScore(b))  \(vm.opponent?.name ?? "Rival")")
                                    .font(PixelFont.headlineSmall)
                                    .foregroundColor(Ds.red)
                                    .multilineTextAlignment(.center)
                                if let side = b?.forfeitedBy {
                                    Text(side == vm.myKey ? "Te rendiste" : "\(vm.opponent?.name ?? "Tu rival") se rindió")
                                        .font(PixelFont.bodyMedium)
                                        .foregroundColor(Ds.inkSoft)
                                }
                                let team = vm.myTeam
                                if !team.isEmpty {
                                    Text("Tu equipo")
                                        .font(PixelFont.bodyMedium)
                                        .foregroundColor(Ds.inkSoft)
                                        .padding(.top, 10)
                                    HStack(spacing: 6) {
                                        ForEach(team) { p in
                                            RemoteImage(url: Sprites.artwork(p.id)).frame(width: 80, height: 80)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        PixelButton(text: "VOLVER AL INICIO", color: Ds.blue, dark: Ds.blueDark, sfx: .confirm) {
                            vm.leaveRoom()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { popped = true }
        }
    }
}

private struct Confetti: View {
    private struct Piece {
        let x, start, speed, spin: Double
    }

    private let pieces: [Piece] = (0..<60).map { i in
        // Fixed pseudo-random layout so the confetti looks the same on every frame.
        let r = { (k: Int) -> Double in
            let v = sin(Double(i * 12 + k) * 12.9898) * 43758.5453
            return v - v.rounded(.down)
        }
        return Piece(x: r(1), start: r(2), speed: r(3), spin: r(4))
    }
    private let colors = [Ds.red, Ds.yellow, Ds.blue, Ds.green, .white]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.5) / 3.5
            Canvas { g, size in
                for (i, piece) in pieces.enumerated() {
                    let y = CGFloat((piece.start + t * (0.6 + piece.speed)).truncatingRemainder(dividingBy: 1)) * size.height * 1.1 - size.height * 0.05
                    let x = CGFloat(piece.x) * size.width + CGFloat(sin(t * 6 + Double(i))) * 14
                    var c = g
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(t * 720 * (piece.spin - 0.5)))
                    c.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)), with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
