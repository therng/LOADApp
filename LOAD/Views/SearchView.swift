import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: AudioPlayerService

    @State private var searchText = ""
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState var isSearchFocused: Bool
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if tracks.isEmpty && !searchText.isEmpty {
                    emptyView
                } else {
                    trackList
                }
            }
            .searchable(text: $searchText, placement: .automatic)
            .onChange(of: isSearchFocused) { _, newValue in
                // When the search field becomes presented, automatically focus it
                if newValue {
                    isSearchFocused = true
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
            .navigationTitle(searchText.isEmpty ? "Search" : searchText)
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
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                tracks = try await APIService.shared.searchTracks(query: q)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // Insert selected track to play right after the current one.
    // No new APIs needed: rebuild queue and call setQueue().
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
