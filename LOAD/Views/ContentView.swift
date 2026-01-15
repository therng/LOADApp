import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab: Int = 2
    @State private var isFullPlayerPresented = false
    // Shared state between Search and History
    @State private var searchText = ""
    @State private var isSearchPresented: Bool = false

    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Local", systemImage: "folder", value: 0, role: .none) {
                LocalDocumentBrowser()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
                HistoryView(selectedTab: $selectedTab, searchText: $searchText, isSearchPresented: $isSearchPresented)
            }
            Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                SearchView(
                    searchText: $searchText,
                    isSearchPresented: $isSearchPresented
                )
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabViewStyle(.sidebarAdaptable)
        .searchToolbarBehavior(.minimize)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: player.currentTrack != nil) {
            MiniPlayerView(isFullPlayerPresented: $isFullPlayerPresented)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onChange(of: selectedTab) { _, _ in
            Haptics.selection()
        }
        .sheet(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .presentationDragIndicator(.hidden)
                .ignoresSafeArea(edges: .all)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService.shared)
}
