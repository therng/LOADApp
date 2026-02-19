import SwiftUI

@main
struct LOADApp: App {
    @State private var navigationManager = AppNavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(navigationManager)
                .environment(AudioPlayerService.shared)
                .task {
                    await APIService.shared.warmUp()
                }
        }
    }
}
