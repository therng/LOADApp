import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab = 0
    @State private var isFullPlayerPresented = false
    
    var body: some View {
        TabView(selection: $selectedTab){
            Tab("Player", systemImage: "play.house", value: 0) {
                FullPlayerView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
                HistoryView()
            }
            Tab("Queue", systemImage: "list.bullet.rectangle.portrait", value: 2) {
                QueueView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search ) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: selectedTab != 0 && player.currentTrack != nil) {
            MiniPlayerView(isFullPlayerPresented: $isFullPlayerPresented)
        }
        .sheet(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
