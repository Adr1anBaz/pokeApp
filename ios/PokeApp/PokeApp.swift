import SwiftUI

@main
struct PokeApp: App {
    @StateObject private var vm = GameViewModel()
    @StateObject private var fontLoader = RemoteFontLoader()

    var body: some Scene {
        WindowGroup {
            RootView(vm: vm)
                // Re-render once the pixel fonts are registered.
                .id(fontLoader.isReady)
                .preferredColorScheme(.light)
                .task {
                    _ = Sound.shared
                    await fontLoader.prepare()
                }
        }
    }
}

/// Shows the current screen with a fade, on the dark DS frame (port of MainActivity.kt).
struct RootView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        ZStack {
            Ds.ink.ignoresSafeArea()
            screen
                .id(vm.screen)
                .transition(.opacity)
        }
    }

    @ViewBuilder private var screen: some View {
        switch vm.screen {
        case .onboarding: OnboardingView(vm: vm)
        case .lobby: LobbyView(vm: vm)
        case .join: JoinView(vm: vm)
        case .waitingRoom: WaitingRoomView(vm: vm)
        case .teamSelect: TeamSelectionView(vm: vm)
        case .battle: BattleView(vm: vm)
        case .result: ResultView(vm: vm)
        }
    }
}
