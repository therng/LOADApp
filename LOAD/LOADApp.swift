
import SwiftUI

@main
struct LOADApp: App {
    var body: some Scene {
        WindowGroup {
       ContentView()
                .environment(AudioPlayerService.shared)
                .task {
                    await APIService.shared.warmUp()
                }
        }
    }
}
