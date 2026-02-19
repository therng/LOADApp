import SwiftUI
import SafariServices

struct HistoryDetailView: View {
    let searchId: String
    let preloadedResponse: SearchResponse?
    
    @Environment(AudioPlayerService.self) var player
    @State private var searchResponse: SearchResponse?
    @State private var metadata: ITunesTrackMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariURLItem: SafariURLItem?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var sortOption: HistorySortOption = .relevance
    @State private var isAscending: Bool = true
    @State private var artistToShow: ArtistDisplayItem?
    
    // Beatport Search State
//    @State private var showBeatportAlert = false
//    @State private var beatportArtist = ""
//    @State private var beatportTitle = ""
//    @State private var beatportMix = ""
//    
    // Banner State

    
    init(searchId: String, preloadedResponse: SearchResponse? = nil) {
        self.searchId = searchId
        self.preloadedResponse = preloadedResponse
    }
    
    var body: some View {
        ScrollView {
            content
        }
        
        .refreshable {
            await fetch()
        }
        .navigationTitle(searchResponse?.query ?? "")
        .navigationBarTitleDisplayMode(.inline)
//        .beatportSearchAlert(isPresented: $showBeatportAlert, artist: $beatportArtist, title: $beatportTitle, mix: $beatportMix)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    sortMenuButtons
                        .background(.clear)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .contentShape(.circle)
                }
            }
        }
        .task(id: searchId) {
            // Clear previous state to avoid stale UI when searchId changes
            searchResponse = nil
            errorMessage = nil

            if let preloaded = preloadedResponse {
                searchResponse = preloaded
            } else {
                await fetch()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && searchResponse == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
        } else if let response = searchResponse {
            resultsView(for: response)
        } else if let message = errorMessage {
            ContentUnavailableView {
                Label("Couldn't load results", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .padding(.top, 50)
        } else {
            ContentUnavailableView(
                "No Data",
                systemImage: "questionmark",
                description: Text("There is nothing to show right now.")
            )
            .padding(.top, 50)
        }
    }
    
    @ViewBuilder
    private func resultsView(for response: SearchResponse) -> some View {
        let results = sortOption.sort(response.results, ascending: isAscending)
        
        if results.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("This search didn't return any tracks.")
            )
            .padding(.top, 50)
        } else {
            LazyVStack(spacing: 15) {
                ForEach(results) { track in
                    TrackRow(
                        track: track,
                        showSaveAction: true,
                        onPlay: {
                            Haptics.impact()
                            if player.currentTrack?.id == track.id {
                                player.togglePlayPause()
                            } else {
                                if let index = results.firstIndex(where: { $0.id == track.id }) {
                                    player.setQueue(results, startAt: index)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var sortMenuButtons: some View {
        ForEach(HistorySortOption.allCases) { option in
            Button {
                if sortOption == option {
                    if option != .relevance {
                        isAscending.toggle()
                    }
                } else {
                    sortOption = option
                    isAscending = true
                }
            } label: {
                let isActive = sortOption == option
                let title = option.displayName(isActive: isActive, isAscending: isAscending)
                Label {
                    Text(title)
                        .fontWeight(isActive ? .semibold : .regular)
                } icon: {
                    Image(systemName: option.systemIcon)
                        .foregroundStyle(isActive ? .blue : .primary)
                }
            }
        }
    }
    
    @MainActor
    private func fetch() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.fetchHistoryItem(with: searchId)
            self.searchResponse = response
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// Wrapper struct to make artist name identifiable for navigation
private struct ArtistDisplayItem: Identifiable, Hashable {
    let id: Int
    let name: String
}

// Wrapper struct to make URL identifiable for Safari sheet
private struct SafariURLItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private enum HistorySortOption: String, CaseIterable, Identifiable {
    case relevance, title, artist, duration

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .relevance: return "calendar"
        case .title: return "music.note"
        case .artist: return "person.fill"
        case .duration: return "clock.fill"
        }
    }

    func displayName(isActive: Bool, isAscending: Bool) -> String {
        let name = rawValue.capitalized
        if !isActive || self == .relevance { return name }
        return name + (isAscending ? " ↑" : " ↓")
    }
    
    func sort(_ tracks: [Track], ascending: Bool) -> [Track] {
        switch self {
        case .relevance:
            return tracks
        case .title:
            return tracks.sorted {
                let res = $0.title.localizedCaseInsensitiveCompare($1.title)
                return ascending ? res == .orderedAscending : res == .orderedDescending
            }
        case .artist:
            return tracks.sorted {
                let res = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                return ascending ? res == .orderedAscending : res == .orderedDescending
            }
        case .duration:
            return tracks.sorted { ascending ? $0.duration < $1.duration : $0.duration > $1.duration }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(searchId: "6990ee6b86b9ce03158ecf2f")
    }
    .environment(AudioPlayerService.shared)
}
