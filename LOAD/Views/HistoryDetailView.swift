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
    @State private var isAscending: Bool = true
    
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
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
        }
        .task(id: searchId) {
            await fetch()
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                SafariView(url: url)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
            }
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
                let title = option.displayName(isActive: sortOption == option, isAscending: isAscending)
                Label(title, systemImage: option.systemIcon)
            }
        }
    }
    
    @MainActor
    private func fetch(force: Bool = false) async {
        guard !isLoading else { return }
        if searchResponse != nil && !force { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.fetchSearchResult(id: searchId)
            self.searchResponse = response
        } catch is CancellationError {
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
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
