import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: AudioPlayerService

    @StateObject private var searchHistory = SearchHistoryService.shared
    @State private var searchText = ""
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState var isSearchFocused: Bool
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var showClearRecentAlert = false

    private let suggestedQueries = [
        "Chill beats",
        "Night drive",
        "Acoustic covers",
        "Focus playlist",
        "Throwback hits",
        "Workout energy"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    discoveryList
                } else if tracks.isEmpty {
                    emptyView
                } else {
                    trackList
                }
            }
            .searchable(text: $searchText, placement: .automatic)
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tracks = []
                    errorMessage = nil
                }
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
    }

    private var discoveryList: some View {
        List {
            if searchHistory.recentQueries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No recent searches", systemImage: "clock")
                    } description: {
                        Text("Search for artists, tracks, or playlists to see them here.")
                    }
                }
            } else {
                Section {
                    ForEach(searchHistory.recentQueries, id: \.self) { query in
                        Button {
                            startSearch(query)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                searchHistory.remove(query)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear") {
                            showClearRecentAlert = true
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }

            Section {
                ForEach(suggestedQueries, id: \.self) { suggestion in
                    Button {
                        startSearch(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.secondary)
                            Text(suggestion)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Suggested Searches")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Use keywords like mood, genre, or activity.", systemImage: "lightbulb")
                    Label("Try combining artist + vibe, e.g. “Lofi study.”", systemImage: "wand.and.stars")
                    Label("Tap the play button on any result to queue quickly.", systemImage: "play.circle")
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(.vertical, 4)
            } header: {
                Text("Search Tips")
            }
        }
        .listStyle(.insetGrouped)
        .alert("Clear recent searches?", isPresented: $showClearRecentAlert) {
            Button("Clear All", role: .destructive) {
                searchHistory.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the recent searches shown on this device.")
        }
    }

    private var trackList: some View {
        List {
            ForEach(tracks) { track in
                TrackRow(track: track)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tap = set queue + play now
                        player.setQueue(tracks, startAt: track)
                        player.play(track: track)
                    }
                    .contextMenu {
                        Button("Play Now", systemImage: "play.fill") {
                            player.setQueue(tracks, startAt: track)
                            player.play(track: track)
                        }

                        Button("Play Next", systemImage: "text.insert") {
                            queueAsNext(track)
                        }

                        TrackActionMenuItems(track: track) { url in
                            safariURL = url
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Save", systemImage: "arrow.down.circle") {
                            safariURL = track.download
                        }
                        .tint(.blue)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.automatic)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2)
                .foregroundStyle(.secondary)
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

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tracks found")
                .font(.headline)
            Text("Try a different search")
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    private func performSearch() {
        startSearch(searchText)
    }

    private func startSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        if searchText != q {
            searchText = q
        }
        isLoading = true
        errorMessage = nil
        tracks = []
        Task {
            do {
                tracks = try await APIService.shared.searchTracks(query: q)
                isLoading = false
                searchHistory.add(q)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    private func queueAsNext(_ track: Track) {
        // Base queue: if player already has a queue, use it; otherwise use current search results.
        var newQueue = player.queue.isEmpty ? tracks : player.queue

        // Remove if already in queue (avoid duplicates)
        if let existing = newQueue.firstIndex(where: { $0.id == track.id }) {
            newQueue.remove(at: existing)
        }

        // Determine current index
        let current: Track? = player.currentTrack
        let currentIdx: Int? = {
            if let idx = player.queueIndex { return idx }
            if let current, let inferred = newQueue.firstIndex(where: { $0.id == current.id }) { return inferred }
            return nil
        }()

        let insertAt: Int = {
            if let currentIdx {
                return min(currentIdx + 1, newQueue.count)
            } else {
                return min(1, newQueue.count)
            }
        }()

        newQueue.insert(track, at: insertAt)

        // Preserve "current track" position if possible
        if let current {
            player.setQueue(newQueue, startAt: current)
        } else {
            player.setQueue(newQueue, startAt: newQueue.first)
        }
    }
}
