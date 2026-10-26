import SwiftUI

@main
struct PokeApp: App {
    @StateObject private var config = AppConfig()
    @StateObject private var fontLoader = RemoteFontLoader()

    var body: some Scene {
        WindowGroup {
            Group {
                if config.hasServer {
                    if config.roomCode.isEmpty {
                        LobbyView(config: config)
                    } else {
                        WaitingRoomView(config: config)
                    }
                } else {
                    OnboardingView(config: config)
                }
            }
            .task {
                await fontLoader.prepare()
            }
        }
    }
}
