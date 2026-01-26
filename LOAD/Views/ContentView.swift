import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab: Int = 2
    @State private var isFullPlayerPresented = false
    // Shared state between Search and History
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false

    
    var body: some View {
        TabView(selection: $selectedTab) {
     
            Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
                // Fixed: Use closure to update state instead of passing bindings directly
                HistoryView { query in
                    searchText = query
                    selectedTab = 2 // Switch to Search tab
                    isSearchPresented = true
                }
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
