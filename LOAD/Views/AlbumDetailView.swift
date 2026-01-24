import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @EnvironmentObject var player: AudioPlayerService
    @State private var tracks: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let message = errorMessage {
                ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(message))
            } else if tracks.isEmpty {
                ContentUnavailableView("No Tracks Found", systemImage: "music.mic", description: Text("No tracks were found for this album."))
            } else {
                List {
                    albumHeader
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical)

                    ForEach(tracks) { item in
                        HStack(spacing: 4) {
                            if item.previewUrl != nil {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.blue)
                                    .frame(width: 25)
                                    .onTapGesture {
                                        playPreview(startingAt: item)
                                    }
                            } else {
                                Text("\(item.trackNumber ?? 0).")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .frame(width: 25, alignment: .center)
                            }
                            
                            TrackRow(track: makeTrack(from: item), isDimmed: item.previewUrl == nil)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playPreview(startingAt: item)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(album.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTracks()
        }
    }
    
    private var albumHeader: some View {
        VStack {
            AsyncImage(url: album.highResArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                            .font(.largeTitle)
                    }
            }
            .frame(width: 200, height: 200)
            .cornerRadius(8)
            .shadow(radius: 5)
            
            Text(album.collectionName)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text(album.artistName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadTracks() async {
        isLoading = true
        do {
            let searchResults = try await APIService.shared.fetchTracksForAlbum(album.collectionId)
            self.tracks = searchResults
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func makeTrack(from item: iTunesSearchResult) -> Track {
        Track(
            artist: item.artistName,
            title: item.trackName ?? "Unknown",
            duration: (item.trackTimeMillis ?? 0) / 1000,
            key: String(item.trackId ?? 0),
            artworkURL: item.highResArtworkURL,
            releaseDate: APIService.yearFormatter.string(from: item.releaseDate),
            customStreamURL: item.previewUrl
        )
    }
    
    private func playPreview(startingAt track: iTunesSearchResult) {
        guard track.previewUrl != nil else { return }
        
        let convertedTracks = tracks.compactMap { item -> Track? in
            guard item.previewUrl != nil else { return nil }
            return makeTrack(from: item)
        }
        
        if let index = convertedTracks.firstIndex(where: { $0.key == String(track.trackId ?? 0) }) {
            player.setQueue(convertedTracks, startAt: index)
        }
    }
}
