import Foundation

enum RoomActions {
    static func leave(config: AppConfig, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(config.serverURL)/room/\(config.roomCode)/leave") else {
            completion("URL de sala inválida")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "playerId": config.playerId
        ])

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(error.localizedDescription)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    completion("No se pudo salir de la sala")
                    return
                }

                config.clearRoom()
                completion(nil)
            }
        }.resume()
    }
}
