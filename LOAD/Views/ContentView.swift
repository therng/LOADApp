import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @StateObject private var searchModel = SearchModel()
    
    @State private var selectedTab: Int = 0
    @State private var isFullPlayerPresented = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Search", systemImage: "magnifyingglass", value: 0, role: .search) {
                NavigationStack {
                    ZStack {
                        // Base Content: History
                        HistoryView { query in
                            searchModel.searchText = query
                            searchModel.performSearch()
                            isFocused = false
                        }
                        
                        // Loading Overlay
                        if searchModel.isLoading {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
                    .navigationDestination(isPresented: $searchModel.shouldNavigateToResult) {
                        if let response = searchModel.presentedResponse {
                            HistoryDetailView(searchId: response.search_id, preloadedResponse: response)
                        }
                    }
                    .searchable(text: $searchModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search")
                    .focused($isFocused)
                    .onSubmit(of: .search) {
                        searchModel.performSearch()
                        isFocused = false
                    }
                    .onAppear {
                        if searchModel.searchText.isEmpty {
                            isFocused = true
                        }
                    
                    }
                        
                }
            }
            
            Tab("Artists", systemImage: "music.mic", value: 1) {
                ArtistTabView()
            }
            
            Tab("Tracks", systemImage: "music.note.list", value: 2) {
                TrackFeedView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSearchActivation(.automatic)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .fullScreenCover(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .ignoresSafeArea(edges: .all)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService.shared)
}

