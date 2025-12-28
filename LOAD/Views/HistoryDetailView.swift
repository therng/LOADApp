import SwiftUI

struct HistoryDetailView: View {
    let searchId: String
    @EnvironmentObject var player: AudioPlayerService
    @State private var searchResponse: SearchResponse?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let response = searchResponse {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(response.results) { track in
                            TrackRow(track: track)
                                .onTapGesture {
                                    player.setQueue(response.results, startAt: track)
                                    player.play(track: track)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(searchResponse?.query ?? "Loading...")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSearchResult()
        }
    }
    
    private func loadSearchResult() async {
        do {
            print("[HistoryDetailView] Fetching search result id=\(searchId)")
            let response = try await APIService.shared.fetchSearchResult(id: searchId)
            await MainActor.run {
                self.searchResponse = response
                self.isLoading = false
            }
            print("[HistoryDetailView] Loaded search result with \(response.results.count) tracks for id=\(searchId)")
        } catch {
            print("[HistoryDetailView] Error loading search result id=\(searchId): \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
