import SwiftUI
import SwiftData

@main
struct LOADApp: App {
    @StateObject private var vm = HomeViewModel.makeDefault()
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(vm)
        }
    }
}
