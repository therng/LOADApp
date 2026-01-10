import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab = 0
    @State private var isFullPlayerPresented = false
    @State private var searchText = ""
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSearchPresented: Bool?
    
    
    var body: some View {
        TabView(selection: $selectedTab){
            Tab("Search", systemImage: "magnifyingglass", value: 0, role: .search) {
                SearchView()
                }
            
            Tab("Queue", systemImage: "list.clipboard.fill", value: 1) {
                QueueView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryView()
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabViewStyle(.sidebarAdaptable)
        .searchToolbarBehavior(.minimize)

        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: selectedTab)

        .tabViewBottomAccessory(isEnabled: player.currentTrack != nil) {
            MiniPlayerView(isFullPlayerPresented: $isFullPlayerPresented)
        }
        .onChange(of: selectedTab) { _, _ in
            Haptics.selection()
        }
        .sheet(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(AudioPlayerService.shared)
}
