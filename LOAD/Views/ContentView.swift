import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab = 0
    
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
                MiniPlayerView()
            }
        }
    }
    

