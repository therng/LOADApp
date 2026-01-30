import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @StateObject private var viewModel = SearchViewModel()
    @State private var isFullPlayerPresented: Bool = false
    
    // Navigation State
    @State private var isSearchPresented: Bool = false
    @State private var selectedTab: Int = 1
    
    // Animation namespace for the zoom transition
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Tab 1: Library
                HistoryView(selectedTab: $selectedTab, searchText: $viewModel.searchText, isSearchPresented: $isSearchPresented)
                    .tabItem {
                        Label((viewModel.errorMessage ?? "").isEmpty ? "Library" : "Error", systemImage: "book")
                    }
                    .tag(1)
                
                // Tab 0: Search
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    } else {
                        ContentUnavailableView(
                            "Search",
                            systemImage: "magnifyingglass",
                            description: Text("Find your next favorite track.")
                        )
                    }
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(0)
            }
            .searchable(
                text: $viewModel.searchText,
                isPresented: $isSearchPresented,
                prompt: Text(viewModel.searchText.isEmpty ? "Search" : viewModel.searchText)
            )
            .onSubmit(of: .search) {
                viewModel.performSearch()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { viewModel.presentedResponse != nil },
                    set: { if !$0 { viewModel.presentedResponse = nil } }
                )
            ) {
                if let response = viewModel.presentedResponse {
                    HistoryDetailView(searchId: response.search_id, preloadedResponse: response)
                }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if !isSearchPresented && !newValue.isEmpty {
                    viewModel.performSearch()
                }
            }
        }
        // MiniPlayer Overlay - replacing iOS 18 tabViewBottomAccessory for compatibility/stability
        .overlay(alignment: .bottom) {
            if player.currentTrack != nil {
                // Adjusting safe area for the tab bar approx height if needed, 
                // but overlay sits on top. We might need to ensure it doesn't block tab bar 
                // or sits above it.
                // Standard pattern: MiniPlayer floats above tab bar content.
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        MiniPlayerView(isFullPlayerPresented: $isFullPlayerPresented)
                            .padding(.bottom, 49 + geometry.safeAreaInsets.bottom) // Lift above standard tab bar
                            .matchedTransitionSource(id: "MINI", in: animation)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .fullScreenCover(isPresented: $isFullPlayerPresented) {
            FullPlayerView()
                .navigationTransition(.zoom(sourceID: "MINI", in: animation))
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.primary)
                .symbolEffect(.pulse)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService.shared)
}
