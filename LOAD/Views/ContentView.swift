import SwiftUI
import Combine
    
    struct ContentView: View {
        @Environment(AudioPlayerService.self) var player
        
        @State private var selectedTab: Int = 0
        
        var body: some View {
            ZStack {
                TabView(selection: $selectedTab) {
                    Tab("Search", systemImage: "magnifyingglass", value: 0, role: .search) {
                        SearchTabView()
                    }
                    
                    Tab("", systemImage: "person.2", value: 1) {
                        ArtistTabView()
                    }
                    
                    Tab("", systemImage: "music.note.list", value: 2) {
                        TrackFeedView()
                    }
                }
                
                .tabViewStyle(.automatic)
                .tabViewSearchActivation(.automatic)
                .tabBarMinimizeBehavior(.onScrollDown)
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
    }

#Preview {
    ContentView()
        .environment(AudioPlayerService.shared)
}




