import SwiftUI

struct TrackFeedView: View {
    @StateObject private var viewModel = TrackFeedViewModel()
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if viewModel.tracks.isEmpty {
                    emptyStateView
                } else {
                    trackListView
                }
            }
            .navigationTitle("Tracks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.fetchLatestTracks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var trackListView: some View {
        List(viewModel.tracks) { item in
            let track = makeTrack(from: item)
            AlbumTrackRowView(
                item: item,
                track: track,
                onPlay: { playPreview(track: track) },
                onCopy: { copyToClipboard(track: track) }
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Recent Tracks",
            systemImage: "music.note.list",
            description: Text("Follow some artists to see their latest tracks here.")
        )
    }
    
    private func makeTrack(from item: iTunesSearchResult) -> Track {
        Track(
            artist: item.artistName,
            title: item.trackName ?? "Unknown",
            duration: (item.trackTimeMillis ?? 0) / 1000,
            key: String(item.trackId ?? 0),
            artworkURL: item.highResArtworkURL,
            releaseDate: item.releaseDate.map { APIService.yearFormatter.string(from: $0) },
            customStreamURL: item.previewUrl
        )
    }

    private func playPreview(track: Track) {
        guard track.customStreamURL != nil else { return }
        Haptics.impact()
        
        let playableTracks = viewModel.tracks.compactMap { makeTrack(from: $0) }.filter { $0.customStreamURL != nil }
        
        if let index = playableTracks.firstIndex(where: { $0.key == track.key }) {
            player.setQueue(playableTracks, startAt: index)
        }
    }
    
    private func copyToClipboard(track: Track) {
        let textToCopy = "\(track.artist) - \(track.title)"
        UIPasteboard.general.string = textToCopy
        Haptics.notify(.success)
    }
}

#Preview {
    TrackFeedView()
        .environmentObject(AudioPlayerService())
}
