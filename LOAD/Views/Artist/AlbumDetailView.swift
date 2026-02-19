import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @State private var tracks: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage = errorMessage {
                ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if tracks.isEmpty {
                ContentUnavailableView("No Tracks Found", systemImage: "music.mic", description: Text("No tracks were found for this album."))
            } else {
                trackListView
            }
        }
        .background(backgroundView)
        .task { await loadTracks() }
    }
    
    private var trackListView: some View {
        List {
            AlbumHeaderView(album: album)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 5)
                .listRowBackground(Color.clear)
            
            ForEach(tracks) { item in
                TrackRowView(item: item)
            }
            
            AlbumFooterView(album: album, tracks: tracks)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 50)
        .ignoresSafeArea(edges: .top)
    }
    
    private var backgroundView: some View {
        GeometryReader { proxy in
            if let url = album.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 30)
                        .overlay(Color.black.opacity(0.3))
                } placeholder: { Color(.systemBackground) }
            } else {
                Color(.systemBackground)
            }
        }
        .ignoresSafeArea()
    }
    
    private func loadTracks() async {
        isLoading = true
        do {
            guard let collectionId = album.collectionId else {
                errorMessage = "Invalid album ID."
                isLoading = false
                return
            }
            let searchResults = try await APIService.shared.fetchTracksForAlbum(collectionId: collectionId)
            self.tracks = searchResults
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct AlbumHeaderView: View {
    let album: iTunesSearchResult
    
    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: album.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(uiColor: .systemGray5))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary).font(.largeTitle))
            }
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 15, y: 5)
            .padding(.bottom, 16)
            
            Text(album.collectionName ?? "Untitled Album").font(.title3.weight(.bold)).multilineTextAlignment(.center).padding(.horizontal, 20).lineLimit(1)
            Text(album.artistName).font(.body).foregroundStyle(Color.accent).multilineTextAlignment(.center).padding(.horizontal).lineLimit(1)
            Text(metadataString).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var metadataString: String {
        var parts: [String] = []
        if let genre = album.primaryGenreName, !genre.isEmpty { parts.append(genre) }
        parts.append(String(Calendar.current.component(.year, from: album.releaseDate ?? Date())))
        return parts.joined(separator: " • ")
    }
}

private struct TrackRowView: View {
    let item: iTunesSearchResult
    @Environment(AudioPlayerService.self) var player
    @Environment(AppNavigationManager.self) var navigationManager
    
    var body: some View {
        TrackRow(
            track: makeTrack(from: item),
            isDimmed: item.previewURL == nil,
            onPlay: {
                if player.currentTrack?.key == String(item.trackId ?? 0) {
                    player.togglePlayPause()
                } else {
                    playPreview(startingAt: item)
                }
            },
            onCopy: {
                copyToClipboard(track: item)
            }
        )
        .listRowBackground(Rectangle().fill(.clear))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                let query = "\(item.artistName) - \(item.trackName ?? "")"
                navigationManager.triggerSearch(query: query)
            } label: {
                Label("Download", systemImage: "arrow.down")
            }
            .tint(.blue)
        }
    }
    
    private func makeTrack(from item: iTunesSearchResult) -> Track {
        Track(
            artist: item.artistName,
            title: item.trackName ?? "Unknown",
            duration: (item.trackTimeMillis ?? 0) / 1000,
            key: String(item.trackId ?? 0),
            artworkURL: item.artworkURL,
            releaseDate: item.releaseDate.map { APIService.yearFormatter.string(from: $0) },
            customStreamURL: item.previewURL
        )
    }
    
    private func playPreview(startingAt trackItem: iTunesSearchResult) {
        let playableTracks = [makeTrack(from: trackItem)]
        guard !playableTracks.isEmpty else { return }
        player.setQueue(playableTracks, startAt: 0)
    }

    private func copyToClipboard(track: iTunesSearchResult) {
        UIPasteboard.general.string = "\(track.artistName) - \(track.trackName ?? "Unknown Track")"
        Haptics.notify(.success)
    }
}

private struct AlbumFooterView: View {
    let album: iTunesSearchResult
    let tracks: [iTunesSearchResult]
    
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedReleaseDate).font(.footnote).foregroundStyle(.secondary)
            Text("\(tracks.count) songs, \(formattedTotalDuration)").font(.footnote).foregroundStyle(.secondary)
            if let copyright = album.copyright, !copyright.isEmpty {
                Text(copyright).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.leading).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    private var formattedReleaseDate: String {
        Self.fullDateFormatter.string(from: album.releaseDate ?? Date())
    }
    
    private var formattedTotalDuration: String {
        let totalMillis = tracks.reduce(0) { $0 + ($1.trackTimeMillis ?? 0) }
        let totalSeconds = Double(totalMillis) / 1000.0
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: totalSeconds) ?? ""
    }
}

