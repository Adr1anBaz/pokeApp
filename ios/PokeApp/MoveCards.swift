import SwiftUI

private let cardGap: CGFloat = 10
private let maxCardHeight: CGFloat = 165
private let hintHeight: CGFloat = 26

/// The 4 moves as a 2x2 hand of cards in the same style as the team-selection cards:
/// a Card-Jitsu tab with the type symbol and a big power number, and a window with the details.
/// Port of android/.../ui/battle/MoveCards.kt.
struct CardHand: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject var director: BattleDirector
    let onForfeit: () -> Void

    @State private var played: Int?

    private var canMove: Bool {
        guard let b = vm.battle, let me = director.mine else { return false }
        return !director.busy && b.status == "waiting_moves" && b.winner == nil && !vm.waitingForOpponent
            && b.battleNumber == director.battleNumber && me.visible && !vm.loading
    }

    var body: some View {
        let moves = director.mine?.moves ?? []
        GeometryReader { geo in
            let cardHeight = min((geo.size.height - hintHeight - cardGap * 2) / 2, maxCardHeight)
            VStack(spacing: cardGap) {
                // Hint and forfeit button share one row, so the button can never be pushed off screen.
                HStack(spacing: 8) {
                    Text(canMove ? "▼ Elige un ataque ▼" : vm.waitingForOpponent ? "Esperando al rival…" : "")
                        .font(PixelFont.titleSmall)
                        .foregroundColor(Ds.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                    if director.mine != nil && vm.battle?.winner == nil {
                        Button {
                            Sound.shared.play(.select)
                            onForfeit()
                        } label: {
                            Text("RENDIRSE")
                                .font(PixelFont.labelMedium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Ds.redDark))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5))
                        }
                        .fixedSize()
                    }
                }
                .frame(height: hintHeight)

                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: cardGap) {
                        ForEach(0..<2, id: \.self) { col in
                            cell(index: row * 2 + col, moves: moves)
                                // Each card gets exactly half the row, whatever its text needs.
                                .frame(width: max((geo.size.width - cardGap) / 2, 0), height: max(cardHeight, 0))
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(LinearGradient(colors: [Color(hex: 0x3A4450), Ds.ink], startPoint: .top, endPoint: .bottom))
        .onChange(of: canMove) { value in if value { played = nil } }
    }

    @ViewBuilder private func cell(index: Int, moves: [Move]) -> some View {
        if vm.waitingForOpponent {
            CardBack(index: index)
        } else if index < moves.count {
            let m = moves[index]
            MoveCard(move: m, index: index, raised: canMove, played: played == m.id, foeTypes: director.theirs?.types) {
                played = m.id
                vm.sendMove(m.id)
            }
        } else {
            Color.clear
        }
    }
}

private struct MoveCard: View {
    let move: Move
    let index: Int
    let raised: Bool
    let played: Bool
    let foeTypes: [String]?
    let onPlay: () -> Void

    @ObservedObject private var names = MoveNames.shared

    /// -1 = played (flies up), 0 = in hand, 1 = lowered while the turn animates.
    private var lift: CGFloat { played ? -1 : raised ? 0 : 1 }

    var body: some View {
        let style = PokeTypes.style(move.type)
        let power = move.power.map { String($0) } ?? "–"
        HStack(spacing: 0) {
            // Card-Jitsu tab: type symbol + big power number, sitting on the frame.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RemoteImage(url: Sprites.typeIcon(move.type))
                    // Up to 38 pt, smaller when the card is short.
                    .frame(maxWidth: 38, maxHeight: 38)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white, lineWidth: 2))
                Spacer(minLength: 0)
                Text(power)
                    .font(PixelFont.title((move.power ?? 0) >= 100 ? 18 : 23))
                    .foregroundColor(.white)
                    .shadow(color: Ds.ink, radius: 0, x: 0, y: 2.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text("POTENCIA")
                    .font(PixelFont.body(9))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .frame(width: 58)
            .frame(maxHeight: .infinity)

            // Window with the details, like the artwork window of the team cards.
            VStack(alignment: .leading, spacing: 0) {
                Text(names.name(move))
                    .font(PixelFont.titleMedium.bold())
                    .foregroundColor(Ds.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 2)
                TypeBadge(type: move.type ?? "normal")
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    ClassChip(damageClass: move.damageClass)
                    EffectivenessChip(eff: PokeTypes.serverEffectiveness(move.type, foeTypes))
                }
                Spacer(minLength: 2)
                AccuracyBar(accuracy: move.accuracy ?? 100, color: style.dark)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xF4F0E4), style.color.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [style.color, style.dark], startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.35), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture {
            guard raised && !played else { return }
            Sound.shared.play(.card)
            onPlay()
        }
        .offset(y: lift < 0 ? lift * 240 : lift * 18)
        .scaleEffect(lift < 0 ? 1 - lift * 0.12 : 1 - lift * 0.04)
        .rotationEffect(.degrees(lift < 0 ? Double(lift) * 8 : 0))
        .opacity(lift < 0 ? Double(1 + lift) : Double(1 - lift * 0.45))
        .animation(.easeOut(duration: played ? 0.38 : 0.28).delay(raised && !played ? Double(index) * 0.06 : 0), value: lift)
    }
}

private struct ClassChip: View {
    let damageClass: String?

    var body: some View {
        let (label, color): (String, Color) = damageClass == "special" ? ("ESPECIAL", Color(hex: 0x5060C0))
            : damageClass == "status" ? ("ESTADO", Ds.inkSoft)
            : ("FÍSICO", Color(hex: 0xC05030))
        Text(label)
            .font(PixelFont.labelSmall)
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 6).fill(color))
    }
}

private struct AccuracyBar: View {
    let accuracy: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("PREC.")
                .font(PixelFont.labelSmall)
                .foregroundColor(Ds.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Ds.ink.opacity(0.15)
                    color.frame(width: proxy.size.width * CGFloat(min(max(Double(accuracy) / 100, 0.05), 1)))
                }
            }
            .frame(height: 7)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text("\(accuracy)%")
                .font(PixelFont.labelMedium)
                .foregroundColor(Ds.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Hint against the current rival, computed the same way the server applies it.
private struct EffectivenessChip: View {
    let eff: Double

    var body: some View {
        if eff != 1 {
            Text(eff > 1 ? "¡EFICAZ!" : "POCO EFICAZ")
                .font(PixelFont.labelSmall)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 6).fill(eff > 1 ? Ds.green : Ds.inkSoft))
        }
    }
}

private struct CardBack: View {
    let index: Int

    var body: some View {
        TimelineView(.animation) { context in
            let wobble = sin((context.date.timeIntervalSinceReferenceDate - Double(index) * 0.12) / 0.7 * Double.pi)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Ds.red, Ds.redDark], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Ds.yellow.opacity(0.85), lineWidth: 3)
                Pokeball(size: 46)
            }
            .rotationEffect(.degrees(wobble * 1.5))
            .offset(y: CGFloat(wobble) * 3)
        }
        .frame(maxWidth: .infinity)
    }
}
