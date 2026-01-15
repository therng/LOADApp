
import SwiftUI

@main
struct LOADApp: App {
    @StateObject private var player = AudioPlayerService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .task {
                    await APIService.shared.warmUp()
                }
        }
    }
}
