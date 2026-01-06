import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab){
            Tab("Queue", systemImage: "list.bullet.rectangle.portrait", value: 0) {
                QueueView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 1, role: .search ) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(content: CustomAccessoryView.init)
    }
}

struct CustomAccessoryView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var isNowPlayingPresented = false

    var body: some View {
        Group {
            if player.currentTrack != nil {
                switch placement {
                case .expanded:
                    MiniPlayerView(isFullPlayerPresented: $isNowPlayingPresented)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                default:
                    MiniPlayerView(isFullPlayerPresented: $isNowPlayingPresented)
                }
            }
        }
        .sheet(isPresented: $isNowPlayingPresented) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
