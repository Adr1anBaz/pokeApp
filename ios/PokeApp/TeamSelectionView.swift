import SwiftUI

struct PokemonListResponse: Codable {
    let pokemon: [Pokemon]
}

struct Pokemon: Codable, Identifiable {
    let id: Int
    let name: String
    let sprite: String?
    let types: [String]
    let stats: [String: Int]
}

struct TeamSelection {
    var order1: Int?
    var order2: Int?
    var order3: Int?

    var isComplete: Bool { order1 != nil && order2 != nil && order3 != nil }
    var orderedIDs: [Int] { [order1, order2, order3].compactMap { $0 } }
    var payload: [[String: Any]] {
        [["pokemonId": order1 as Any, "order": 1], ["pokemonId": order2 as Any, "order": 2], ["pokemonId": order3 as Any, "order": 3]]
    }

    mutating func assign(_ pokemonID: Int, to order: Int) {
        if order1 == pokemonID { order1 = nil }
        if order2 == pokemonID { order2 = nil }
        if order3 == pokemonID { order3 = nil }
        switch order {
        case 1: order1 = pokemonID
        case 2: order2 = pokemonID
        case 3: order3 = pokemonID
        default: break
        }
    }

    func order(for pokemonID: Int) -> Int? {
        if order1 == pokemonID { return 1 }
        if order2 == pokemonID { return 2 }
        if order3 == pokemonID { return 3 }
        return nil
    }

    func id(at order: Int) -> Int? {
        switch order {
        case 1: return order1
        case 2: return order2
        case 3: return order3
        default: return nil
        }
    }
}

struct TeamSelectionView: View {
    @ObservedObject var config: AppConfig
    @State private var pokemon: [Pokemon] = []
    @State private var selection = TeamSelection()
    @State private var activeOrder = 1
    @State private var message = ""
    @State private var isLoading = false
    @State private var showBattle = false
    @State private var showLeaveConfirmation = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let pollingTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [DSColor.skyTop.opacity(0.46), DSColor.paper, DSColor.yellow.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    draftHeader

                    if isLoading && pokemon.isEmpty {
                        ProgressView("Barajando cartas...")
                            .font(DSFont.body(15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(pokemon) { candidate in
                                PokemonDraftCard(
                                    pokemon: candidate,
                                    selectedOrder: selection.order(for: candidate.id),
                                    isTargeted: activeOrder == selection.order(for: candidate.id)
                                ) {
                                    choose(candidate)
                                }
                            }
                        }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(DSFont.body(13, weight: .bold))
                            .foregroundStyle(message.hasPrefix("Error") ? DSColor.red : DSColor.grassDark)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { teamTray }
        .navigationTitle("Elige tu equipo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Salir") { showLeaveConfirmation = true }
            }
        }
        .confirmationDialog("¿Salir de la sala?", isPresented: $showLeaveConfirmation) {
            Button("Salir", role: .destructive) {
                RoomActions.leave(config: config) { error in
                    if let error { message = "Error: \(error)" }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .background {
            NavigationLink(destination: BattleView(config: config), isActive: $showBattle) { EmptyView() }.hidden()
        }
        .onAppear {
            fetchPokemon()
            checkBattleStatus()
        }
        .onReceive(pollingTimer) { _ in checkBattleStatus() }
    }

    private var draftHeader: some View {
        DSPanel {
            VStack(alignment: .leading, spacing: 7) {
                Text("DRAFT DE EQUIPO")
                    .font(DSFont.title(13))
                    .foregroundStyle(DSColor.ink)
                Text("Toca una carta para ocupar el espacio \(activeOrder). No puedes repetir Pokémon.")
                    .font(DSFont.body(14, weight: .medium))
                    .foregroundStyle(DSColor.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var teamTray: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { order in
                    TeamSlot(
                        order: order,
                        pokemon: pokemon.first { $0.id == selection.id(at: order) },
                        isActive: activeOrder == order
                    ) { activeOrder = order }
                }
            }

            DSButton(tone: .primary, action: submitTeam) {
                Text(selection.isComplete ? "CONFIRMAR EQUIPO" : "ELIGE 3 POKÉMON")
            }
            .disabled(!selection.isComplete || isLoading)
            .opacity(selection.isComplete ? 1 : 0.58)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.ink).frame(height: 3) }
    }

    private func choose(_ candidate: Pokemon) {
        if let currentOrder = selection.order(for: candidate.id) {
            activeOrder = currentOrder
            return
        }
        selection.assign(candidate.id, to: activeOrder)
        activeOrder = (1...3).first { selection.id(at: $0) == nil } ?? activeOrder
    }

    private func checkBattleStatus() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let decoded = try? JSONDecoder().decode(RoomStatus.self, from: data) else { return }
            DispatchQueue.main.async { if decoded.status == "battle" { showBattle = true } }
        }.resume()
    }

    private func fetchPokemon() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/pokemon") else { message = "Error: URL inválida"; return }
        var request = URLRequest(url: url)
        request.setValue(config.playerId, forHTTPHeaderField: "playerid")
        isLoading = true
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error { message = "Error: \(error.localizedDescription)"; return }
                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode), let data,
                      let decoded = try? JSONDecoder().decode(PokemonListResponse.self, from: data) else {
                    message = "Error: no se pudieron cargar los Pokémon"; return
                }
                pokemon = decoded.pokemon
                message = ""
            }
        }.resume()
    }

    private func submitTeam() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/team") else { message = "Error: URL inválida"; return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["playerId": config.playerId, "team": selection.payload])
        isLoading = true
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error { isLoading = false; message = "Error: \(error.localizedDescription)"; return }
                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else { isLoading = false; message = "Error: el servidor rechazó el equipo"; return }
                message = "Equipo enviado. Marcando como listo..."
                markReady()
            }
        }.resume()
    }

    private func markReady() {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/ready") else { isLoading = false; message = "Error: URL inválida"; return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["playerId": config.playerId])
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error { message = "Error: \(error.localizedDescription)"; return }
                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else { message = "Error: no se pudo marcar como listo"; return }
                message = "Listo. Esperando al otro jugador..."
            }
        }.resume()
    }
}

private struct PokemonDraftCard: View {
    let pokemon: Pokemon
    let selectedOrder: Int?
    let isTargeted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pokemon.name.uppercased())
                        .font(DSFont.body(14, weight: .bold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text("HP \(stat("hp"))")
                        .font(DSFont.body(11, weight: .bold))
                }
                .foregroundStyle(DSColor.ink)

                ZStack(alignment: .topTrailing) {
                    PokemonArtwork(pokemon: pokemon)
                        .frame(height: 106)
                        .frame(maxWidth: .infinity)
                        .background(typeColor.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                    if let selectedOrder {
                        Text("#\(selectedOrder)")
                            .font(DSFont.title(11))
                            .foregroundStyle(DSColor.paper)
                            .padding(7)
                            .background(DSColor.red, in: Circle())
                            .padding(5)
                    }
                }
                .padding(.top, 5)

                HStack(spacing: 4) {
                    ForEach(pokemon.types, id: \.self) { type in TypeBadge(type: type) }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)

                VStack(spacing: 4) {
                    StatBar(label: "ATK", value: stat("attack"), color: DSColor.red)
                    StatBar(label: "DEF", value: stat("defense"), color: DSColor.blue)
                    StatBar(label: "VEL", value: stat("speed"), color: DSColor.grassDark)
                }
            }
            .padding(9)
            .background(DSColor.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isTargeted ? DSColor.ink : typeColor, lineWidth: isTargeted ? 5 : 4)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(typeColor).frame(height: 7).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .shadow(color: DSColor.ink.opacity(0.25), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pokemon.name), \(selectedOrder.map { "equipo \($0)" } ?? "sin seleccionar")")
    }

    private var typeColor: Color { DSColor.type(pokemon.types.first ?? "normal") }
    private func stat(_ key: String) -> Int { pokemon.stats[key] ?? 0 }
}

private struct PokemonArtwork: View {
    let pokemon: Pokemon
    @State private var useSpriteFallback = false

    private var officialURL: URL? { URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(pokemon.id).png") }
    private var fallbackURL: URL? { URL(string: pokemon.sprite ?? "") }

    var body: some View {
        Group {
            if useSpriteFallback, let fallbackURL {
                AsyncImage(url: fallbackURL, content: imageView, placeholder: placeholder)
            } else {
                AsyncImage(url: officialURL) { phase in
                    if let image = phase.image { imageView(image) }
                    else if phase.error != nil, fallbackURL != nil { Color.clear.onAppear { useSpriteFallback = true } }
                    else { placeholder() }
                }
            }
        }
    }

    @ViewBuilder private func imageView(_ image: Image) -> some View {
        image.resizable().scaledToFit().padding(4)
    }
    @ViewBuilder private func placeholder() -> some View {
        Image(systemName: "pokeball").resizable().scaledToFit().foregroundStyle(DSColor.ink.opacity(0.35)).padding(28)
    }
}

private struct TypeBadge: View {
    let type: String
    var body: some View {
        Text(typeName)
            .font(DSFont.body(8, weight: .bold))
            .foregroundStyle(DSColor.paper)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(DSColor.type(type), in: Capsule())
    }
    private var typeName: String {
        ["normal": "Normal", "fire": "Fuego", "water": "Agua", "electric": "Eléctrico", "grass": "Planta", "ice": "Hielo", "fighting": "Lucha", "poison": "Veneno", "ground": "Tierra", "flying": "Volador", "psychic": "Psíquico", "bug": "Bicho", "rock": "Roca", "ghost": "Fantasma", "dragon": "Dragón", "dark": "Siniestro", "steel": "Acero", "fairy": "Hada"][type.lowercased()] ?? type.capitalized
    }
}

private struct StatBar: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(DSFont.body(8, weight: .bold)).frame(width: 22, alignment: .leading)
            GeometryReader { proxy in
                Capsule().fill(DSColor.ink.opacity(0.12)).overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: proxy.size.width * min(CGFloat(value) / 150, 1))
                }
            }.frame(height: 6)
            Text("\(value)").font(DSFont.body(8, weight: .bold)).frame(width: 18, alignment: .trailing)
        }.foregroundStyle(DSColor.ink)
    }
}

private struct TeamSlot: View {
    let order: Int
    let pokemon: Pokemon?
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(order)").font(DSFont.title(10))
                Text(pokemon?.name.uppercased() ?? "VACÍO")
                    .font(DSFont.body(9, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(pokemon == nil ? "elige carta" : "listo")
                    .font(DSFont.body(8)).foregroundStyle(DSColor.ink.opacity(0.65))
            }
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(pokemon.map { DSColor.type($0.types.first ?? "normal").opacity(0.22) } ?? DSColor.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(isActive ? DSColor.red : DSColor.ink, lineWidth: isActive ? 3 : 2) }
        }.buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { TeamSelectionView(config: AppConfig()) }
}
