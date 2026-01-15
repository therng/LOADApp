import SwiftUI

struct HistoryDetailView: View {
    let searchId: String
    @EnvironmentObject var player: AudioPlayerService
    @State private var searchResponse: SearchResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariURLItem: SafariURLItem?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var sortOption: SortOption = .relevance
    @State private var isAscending: Bool = true
    @State private var artistToShow: ArtistDisplayItem?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let message = errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load results", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            } else if let response = searchResponse {
                let results = sortOption.sort(response.results, ascending: isAscending)
                
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
                                        if let index = results.firstIndex(where: { $0.id == track.id }) {
                                            player.setQueue(results, startAt: index)
                                        }
                                    }
                                    .contextMenu {
                                        TrackActionMenuItems(track: track, onSave: { url in
                                            safariDetent = .medium
                                            safariURLItem = SafariURLItem(url: url)
                                        }, onGoToArtist: { artistName in
                                            self.artistToShow = ArtistDisplayItem(name: artistName)
                                        }, player: player)
                                    }
                            }
                        }
                        .padding()
                    }
                }
            } else {
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    sortMenuButtons
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .contentShape(.circle)
                }
            }
        }
        .task(id: searchId) {
            await fetch()
        }
        .sheet(item: $safariURLItem) { item in
            SafariView(url: item.url)
                .presentationDetents([.medium, .large], selection: $safariDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $artistToShow) { artistItem in
            ArtistDetailView(artistName: artistItem.name)
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

private struct SafariURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

private enum SortOption: String, CaseIterable, Identifiable {
    case relevance, title, artist, duration

    var id: String { rawValue }

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

