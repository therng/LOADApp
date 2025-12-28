import SwiftUI

struct HistoryDetailView: View {
    let searchId: String
    @EnvironmentObject var player: AudioPlayerService
    @State private var searchResponse: SearchResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let message = errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load results", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task { await fetch(force: true) }
                    }
                }
            } else if let response = searchResponse {
                if response.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("This search didn't return any tracks.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(response.results) { track in
                                TrackRow(track: track)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        player.setQueue(response.results, startAt: track)
                                        player.play(track: track)
                                    }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await fetch(force: true)
                    }
                }
            } else {
                // Placeholder state; shouldn't be visible for long
                ContentUnavailableView(
                    "No Data",
                    systemImage: "questionmark",
                    description: Text("There is nothing to show right now.")
                )
            }
        }
        .navigationTitle(searchResponse?.query ?? "Loading…")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: searchId) {
            await fetch()
        }
    }
    
    private func fetch(force: Bool = false) async {
        // Prevent duplicate loads
        let currentlyLoading = await MainActor.run { isLoading }
        if currentlyLoading { return }
        
        // If we already have data and not forcing, do nothing
        let hasData = await MainActor.run { searchResponse != nil }
        if hasData && !force { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await APIService.shared.fetchSearchResult(id: searchId)
            await MainActor.run {
                self.searchResponse = response
                self.isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
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
