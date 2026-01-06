import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab){
            Tab("Player", systemImage: "play.house", value: 0) {
                FullPlayerView()
            }
            Tab("Queue", systemImage: "list.bullet.rectangle.portrait", value: 1) {
                QueueView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search ) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            CustomAccessoryView(selectedTab: $selectedTab)
        }
    }
}

struct CustomAccessoryView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Binding var selectedTab: Int

    private let playerTabIndex = 0

    var body: some View {
        Group {
            if player.currentTrack != nil {
                switch placement {
                case .expanded:
                    MiniPlayerView {
                        selectedTab = playerTabIndex
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                default:
                    MiniPlayerView {
                        selectedTab = playerTabIndex
                    }
                }
            }
        }
    }
}
