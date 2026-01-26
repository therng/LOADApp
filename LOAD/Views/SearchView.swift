import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: AudioPlayerService
    
    // Changed from @State to @Binding to accept state from ContentView
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    
    @State private var searchResults: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Task for handling debounce
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    // Show History when not searching
                    HistoryView(onSelectQuery: { query in
                        searchText = query
                        // Trigger search immediately upon selecting history
                        performSearch(query: query)
                    })
                } else if isLoading {
                    ProgressView("Searching...")
                } else if let error = errorMessage {
                    ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    // Results List
                    List {
                        ForEach(searchResults) { track in
                            Button {
                                playTrack(track)
                            } label: {
                                TrackRow(track: track)
                            }
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    player.addToQueue(track)
                                    Haptics.notify(.success)
                                } label: {
                                    Label("Queue", systemImage: "text.badge.plus")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            // Updated to use isPresented binding
            .searchable(text: $searchText, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs, Artists, URLs")
            .onSubmit(of: .search) {
                performSearch(query: searchText)
            }
            // Trigger search on appear if text exists but no results (e.g. coming from History tab)
            .task {
                if !searchText.isEmpty && searchResults.isEmpty {
                    performSearch(query: searchText)
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                if newValue.isEmpty {
                    searchResults = []
                    errorMessage = nil
                    isLoading = false
                } else {
                    searchTask = Task {
                        // Debounce: Wait 0.5s before searching
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if !Task.isCancelled {
                            performSearch(query: newValue)
                        }
                    }
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (_, tracks) = try await APIService.shared.search(query: query)
                await MainActor.run {
                    self.searchResults = tracks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func playTrack(_ track: Track) {
        Haptics.selection()
        // If clicking a track in search results, play it and queue the rest of the results
        if let index = searchResults.firstIndex(where: { $0.id == track.id }) {
            player.setQueue(searchResults, startAt: index)
        }
    }
}
