import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    
    @State private var selectedTab = 3
    @State private var isFullPlayerPresented = false
    
    // Shared state between Search and History
    @State private var searchText = ""
    @State private var isSearchPresented = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Search", systemImage: "magnifyingglass", value: 0, role: .search) {
                SearchView(
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
                )
            }
            
            Tab("Files", systemImage: "waveform", value: 1) {
              RealtimeAudioWaveView()
            }
            Tab("Local", systemImage: "square.and.arrow.down", value: 2) {
                LocalDocumentBrowser()
            }
            
            Tab("History", systemImage: "clock.arrow.circlepath", value: 3) {
                HistoryView(
                    selectedTab: $selectedTab,
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
                )
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
