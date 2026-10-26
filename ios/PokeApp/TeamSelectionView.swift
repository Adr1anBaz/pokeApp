import SwiftUI

struct TeamSelectionView: View {
    @ObservedObject var vm: GameViewModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        StripedBackground(top: Color(hex: 0x305878), bottom: Color(hex: 0x58A0C8)) {
            VStack(spacing: 0) {
                header
                ErrorBanner(message: vm.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, vm.error == nil ? 0 : 6)

                ZStack {
                    if vm.pokemon.isEmpty {
                        VStack(spacing: 14) {
                            if vm.loading {
                                SpinningPokeball(size: 64)
                                Text("Abriendo sobres…")
                                    .font(PixelFont.headlineSmall)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                Text("(puede tardar unos segundos)")
                                    .font(PixelFont.bodyMedium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            } else {
                                PixelButton(text: "REINTENTAR", fullWidth: false) { vm.loadPokemon() }
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(vm.pokemon.enumerated()), id: \.element.id) { index, p in
                                    let order = vm.selected.firstIndex(of: p.id).map { $0 + 1 }
                                    TradingCard(pokemon: p, order: order, index: index, enabled: !vm.readySent) {
                                        if !vm.selected.contains(p.id) && vm.selected.count < 3 {
                                            Sound.shared.cry(id: p.id, name: p.name)
                                        }
                                        vm.toggleSelection(p.id)
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                PartyTray(vm: vm)
            }
        }
        .onAppear { vm.loadPokemon() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ELIGE TU EQUIPO")
                    .font(PixelFont.headlineSmall)
                    .foregroundColor(Ds.yellow)
                Text("Sala \(vm.roomCode ?? "") · Toca 3 cartas en orden de batalla")
                    .font(PixelFont.bodySmall)
                    .foregroundColor(.white)
            }
            Spacer(minLength: 8)
            let rival = vm.opponent
            Text(rivalLabel(rival))
                .font(PixelFont.labelMedium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(rival?.ready == true ? Ds.green : Ds.blue))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Ds.ink.opacity(0.85))
    }

    private func rivalLabel(_ rival: PlayerInfo?) -> String {
        guard let rival else { return "…" }
        if rival.ready { return "\(rival.name): ¡LISTO!" }
        if rival.hasTeam { return "\(rival.name): equipo OK" }
        return "\(rival.name): eligiendo"
    }
}

private struct TradingCard: View {
    let pokemon: Pokemon
    let order: Int?
    let index: Int
    let enabled: Bool
    let onTap: () -> Void

    @State private var dealt = false

    var body: some View {
        let type = PokeTypes.style(pokemon.types?.first)
        let stats = pokemon.stats ?? [:]
        let selected = order != nil

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pokemon.name.prettyName)
                    .font(PixelFont.titleSmall)
                    .foregroundColor(Ds.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("PS \(stats["hp"].map { String($0) } ?? "?")")
                    .font(PixelFont.labelMedium)
                    .foregroundColor(Ds.redDark)
            }
            ZStack(alignment: .topLeading) {
                RadialGradient(colors: [.white, type.color.opacity(0.35)], center: .center, startRadius: 0, endRadius: 90)
                RemoteImage(url: Sprites.artwork(pokemon.id))
                    .padding(4)
                if let order {
                    // Order badge in the artwork's corner (not over the name).
                    Text("\(order)")
                        .font(PixelFont.headlineSmall)
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Ds.red))
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .padding(4)
                }
            }
            .aspectRatio(1.25, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(type.dark.opacity(0.6), lineWidth: 2))
            HStack(spacing: 4) {
                ForEach(pokemon.types ?? [], id: \.self) { TypeBadge(type: $0) }
            }
            StatLine(label: "ATQ", value: stats["attack"], color: Ds.red)
            StatLine(label: "DEF", value: stats["defense"], color: Ds.blue)
            StatLine(label: "VEL", value: stats["speed"], color: Ds.green)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(LinearGradient(colors: [type.color, type.color.opacity(0.7), .white], startPoint: .top, endPoint: .bottom))
        )
        .padding(selected ? 4 : 3)
        .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Ds.yellow : type.dark))
        .contentShape(Rectangle())
        .onTapGesture {
            guard enabled else { return }
            Sound.shared.play(.select)
            onTap()
        }
        // Cards are dealt in one after another; a selected card lifts a bit.
        .scaleEffect((dealt ? 1 : 0.6) * (selected ? 1.04 : 1))
        .rotationEffect(.degrees(dealt ? 0 : (index % 2 == 0 ? -8 : 8)))
        .offset(y: (dealt ? 0 : 60) - (selected ? 7 : 0))
        .opacity(dealt ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: selected)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.07 * Double(index))) { dealt = true }
        }
    }
}

private struct StatLine: View {
    let label: String
    let value: Int?
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(PixelFont.labelSmall)
                .foregroundColor(Ds.ink)
                .frame(width: 28, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Ds.ink.opacity(0.15))
                    Rectangle()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(min(max(Double(value ?? 0) / 160, 0.03), 1)))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(value.map { String($0) } ?? "?")
                .font(PixelFont.labelSmall)
                .foregroundColor(Ds.ink)
        }
    }
}

/// Bottom tray with the 3 chosen Pokémon and the confirm / ready button.
private struct PartyTray: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        DsPanel(accent: Ds.red, padding: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { slot in
                        slotView(slot)
                    }
                }
                actionArea
                Button("Salir de la sala") { vm.leaveRoom() }
                    .font(PixelFont.bodySmall)
                    .foregroundColor(Ds.inkSoft)
            }
        }
        .padding(10)
    }

    private func slotView(_ slot: Int) -> some View {
        let p: Pokemon? = vm.selected.indices.contains(slot) ? vm.pokemon.first(where: { $0.id == vm.selected[slot] }) : nil
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(p.map { PokeTypes.style($0.types?.first).color.opacity(0.3) } ?? Ds.ink.opacity(0.08))
            Group {
                if let p {
                    PixelSprite(url: Sprites.animatedFront(p.id), fallbackURL: Sprites.front(p.id), scale: 0.42)
                } else {
                    Pokeball(size: 22, greyed: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("\(slot + 1)")
                .font(PixelFont.labelMedium)
                .foregroundColor(Ds.ink)
                .padding(4)
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(p != nil ? Ds.red : Ds.frame.opacity(0.4), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture {
            guard let p, !vm.readySent else { return }
            Sound.shared.play(.select)
            vm.toggleSelection(p.id)
        }
    }

    @ViewBuilder private var actionArea: some View {
        if vm.readySent {
            HStack(spacing: 8) {
                SpinningPokeball(size: 24)
                Text(vm.opponent?.ready == true ? "¡Que empiece la batalla!" : "Esperando a \(vm.opponent?.name ?? "tu rival")…")
                    .font(PixelFont.titleMedium)
                    .foregroundColor(Ds.ink)
            }
            .frame(maxWidth: .infinity)
        } else if vm.teamSent {
            PixelButton(text: "¡LISTO PARA PELEAR!", color: Ds.green, dark: Ds.greenDark, enabled: !vm.loading, sfx: .confirm) {
                vm.markReady()
            }
        } else {
            PixelButton(text: "CONFIRMAR EQUIPO (\(vm.selected.count)/3)", enabled: !vm.loading && vm.selected.count == 3, sfx: .confirm) {
                vm.confirmTeam()
            }
        }
    }
}
