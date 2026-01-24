import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab: Int = 2
    @State private var isFullPlayerPresented = false
    // Shared state between Search and History
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false
    @Namespace private var animation
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Local", systemImage: "folder", value: 0) {
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
                .matchedTransitionSource(id: "MINI", in: animation)
                .onTapGesture {
                    isFullPlayerPresented.toggle()
                }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .fullScreenCover(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 10) {}
                        .navigationTransition(.zoom(sourceID: "MINI", in: animation))
                }
        }
    }
}
#Preview {
         ContentView()
             .environmentObject(AudioPlayerService.shared)
     }
