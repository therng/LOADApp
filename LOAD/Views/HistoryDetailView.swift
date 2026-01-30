import SwiftUI
import SafariServices

struct HistoryDetailView: View {
    let searchId: String
    let preloadedResponse: SearchResponse?
    
    @EnvironmentObject var player: AudioPlayerService
    @State private var searchResponse: SearchResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariURLItem: SafariURLItem?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var sortOption: SortOption = .relevance
    @State private var isAscending: Bool = true
    @State private var artistToShow: ArtistDisplayItem?
    
    // Beatport Search State
    @State private var showBeatportAlert = false
    @State private var beatportArtist = ""
    @State private var beatportTitle = ""
    @State private var beatportMix = ""
    
    init(searchId: String, preloadedResponse: SearchResponse? = nil) {
        self.searchId = searchId
        self.preloadedResponse = preloadedResponse
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await fetch(force: true)
        }
        .navigationTitle(searchResponse?.query ?? "Loading…")
        .navigationBarTitleDisplayMode(.inline)
        .beatportSearchAlert(isPresented: $showBeatportAlert, artist: $beatportArtist, title: $beatportTitle, mix: $beatportMix)
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
            if let preloaded = preloadedResponse {
                self.searchResponse = preloaded
            } else {
                await fetch()
            }
        }
        .sheet(item: $safariURLItem) { item in
            SafariView(url: item.url)
                .presentationDetents([.medium, .large], selection: $safariDetent)
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $artistToShow) { artistItem in
            ArtistDetailView(artistName: artistItem.name)
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
            LazyVStack(spacing: 12) {
                ForEach(results) { track in
                    TrackRow(track: track)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.impact()
                            if let index = results.firstIndex(where: { $0.id == track.id }) {
                                player.setQueue(results, startAt: index)
                            }
                        }
                        .contextMenu {
                            TrackActionMenuItems(
                                track: track,
                                onSave: { url in
                                    safariDetent = .medium
                                    safariURLItem = SafariURLItem(url: url)
                                },
                                onGoToArtist: { artistName in
                                    self.artistToShow = ArtistDisplayItem(name: artistName)
                                },
                                onSearchBeatport: { artist, title, mix in
                                    self.beatportArtist = artist
                                    self.beatportTitle = title
                                    self.beatportMix = mix
                                    self.showBeatportAlert = true
                                },
                                player: player
                            )
                        }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var sortMenuButtons: some View {
        ForEach(SortOption.allCases) { option in
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
    private func fetch(force: Bool = false) async {
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
    let name: String
    var id: String { name }
}

// Wrapper struct to make URL identifiable for Safari sheet
private struct SafariURLItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case relevance, title, artist, duration

    var id: String { rawValue }

// ... (Rest of SortOption enum)

    var systemIcon: String {
        switch self {
        case .relevance: return "star"
        case .title: return "music.note"
        case .artist: return "music.microphone"
        case .duration: return "clock"
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
        HistoryDetailView(searchId: "696fb2e7cf275cab418ac4ad")
    }
    .environmentObject(AudioPlayerService.shared)
}

