import SwiftUI

struct HistoryDetailView: View {
    let searchId: String
    @EnvironmentObject var player: AudioPlayerService
    @State private var searchResponse: SearchResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var sortOption: SortOption = .relevance
    
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
                let results = sortOption.sort(response.results)
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("This search didn't return any tracks.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { track in
                                TrackRow(track: track)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Haptics.impact()
                                        player.setQueue(results, startAt: track)
                                        player.play(track: track)
                                    }
                                    .contextMenu {
                                        TrackActionMenuItems(track: track, onSave: { url in
                                            safariDetent = .medium
                                            safariURL = url
                                        }, player: player)
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
        .toolbar {
            Menu {
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .task(id: searchId) {
            await fetch()
        }
        .sheet(
            isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )
        ) {
            if let safariURL {
                SafariView(url: safariURL)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
            }
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
                player.addHistory(from: response)
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

private enum SortOption: String, CaseIterable, Identifiable {
    case relevance
    case title
    case artist
    case duration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance: return "Relevance"
        case .title: return "Title"
        case .artist: return "Artist"
        case .duration: return "Duration"
        }
    }

    func sort(_ tracks: [Track]) -> [Track] {
        switch self {
        case .relevance:
            return tracks
        case .title:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return tracks.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .duration:
            return tracks.sorted { $0.duration < $1.duration }
        }
    }
}
