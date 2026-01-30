import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var isFullPlayerPresented:  Bool = false
    // Shared state between Search and History
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedResponse: SearchResponse?
    @State private var selectedTab: Int = 1
    @Namespace private var animation
    
    var body: some View {
            TabView(selection: $selectedTab) {
                Tab((errorMessage ?? "").isEmpty ? "Library" : "Error", systemImage: "book", value: 1) {
                    HistoryView(selectedTab: $selectedTab, searchText: $searchText, isSearchPresented: $isSearchPresented)
                }
                Tab("Search", systemImage: "magnifyingglass", value: 0, role: .search) {
                    if isLoading {
                        loadingView
                    } else if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    } else {
                        ContentUnavailableView(
                            "Search",
                            systemImage: "magnifyingglass",
                            description: Text("Find your next favorite track.")
                        )
                    }
                }
            }
            
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: Text(searchText.isEmpty ? "Search" : searchText)
                
            )
            .onSubmit(of: .search) {
                performSearch()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { presentedResponse != nil },
                    set: { if !$0 { presentedResponse = nil } }
                )
            ) {
                if let response = presentedResponse {
                    HistoryDetailView(searchId: response.search_id, preloadedResponse: response)
                }
            }
            // Trigger search if searchText is updated from outside (e.g. HistoryView)
            .onChange(of: searchText) { _, newValue in
                if !isSearchPresented && !newValue.isEmpty {
                    performSearch()
                }
            }
        
            .tabViewSearchActivation(.searchTabSelection)
            .tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory(isEnabled: player.currentTrack != nil) {
                MiniPlayerView(isFullPlayerPresented: $isFullPlayerPresented)
                    .matchedTransitionSource(id: "MINI", in: animation)
            }
            .sensoryFeedback(.selection, trigger: selectedTab)
            .fullScreenCover(isPresented: $isFullPlayerPresented) {
                FullPlayerView()
                    .navigationTransition(.zoom(sourceID: "MINI", in: animation))
            }
        
        }

    private func performSearch() {
        // Dismiss keyboard manually since .searchable focus binding isn't available/reliable here
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        presentedResponse = nil // Reset to ensure navigation triggers fresh
        
        Task {
            do {
                let (searchId, tracks) = try await APIService.shared.search(query: q)
                let response = SearchResponse(search_id: searchId, results: tracks, query: q, count: tracks.count)
                
                await MainActor.run {
                    self.presentedResponse = response
                    Haptics.impact(.medium)
                    self.isLoading = false
                }
            } catch {
                // Ignore cancellation errors
                if let apiError = error as? APIService.APIError, case .cancelled = apiError {
                    return
                }
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }


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
