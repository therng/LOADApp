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

// MARK: - Global Helpers
struct Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
