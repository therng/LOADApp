import SwiftUI

@main
struct LOADApp: App {
    // Shared instance of the player service
    @StateObject private var player = AudioPlayerService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark) // Production music apps often default to dark for better vibe
                .task {
                    // Initialize API service
                    await APIService.shared.warmUp()
                }
        }
    }
}
