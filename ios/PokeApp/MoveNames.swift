import Foundation

/// Spanish move names from PokeAPI (/move/{id}), Latin-American first.
/// Cached in memory and in UserDefaults so each move is fetched only once.
@MainActor
final class MoveNames: ObservableObject {
    static let shared = MoveNames()
    private static let defaultsKey = "moveNamesES"

    @Published private var names: [Int: String] = [:]
    private var requested: Set<Int> = []

    private init() {
        let saved = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        for (key, value) in saved {
            if let id = Int(key) { names[id] = value }
        }
    }

    func name(_ move: Move) -> String { names[move.id] ?? move.name.prettyName }

    func prefetch(_ moves: [Move]) {
        for move in moves where names[move.id] == nil && !requested.contains(move.id) {
            requested.insert(move.id)
            Task { await fetch(move.id) }
        }
    }

    private func fetch(_ id: Int) async {
        guard let url = URL(string: "https://pokeapi.co/api/v2/move/\(id)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["names"] as? [[String: Any]] else {
            requested.remove(id)
            return
        }
        var byLanguage: [String: String] = [:]
        for entry in list {
            if let name = entry["name"] as? String,
               let language = (entry["language"] as? [String: Any])?["name"] as? String {
                byLanguage[language] = name
            }
        }
        guard let spanish = byLanguage["es-419"] ?? byLanguage["es"] else { return }
        names[id] = spanish
        var saved = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        saved[String(id)] = spanish
        UserDefaults.standard.set(saved, forKey: Self.defaultsKey)
    }
}
