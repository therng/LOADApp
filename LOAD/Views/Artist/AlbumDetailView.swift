import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @Environment(AudioPlayerService.self) var player
    @State private var tracks: [iTunesSearchResult] = []
    @State private var playableTracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopiedBanner = false
    
    // Formatter for full date display
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        mainContent
            .background(backgroundView)
            .colorScheme(.dark) // Ensures text is visible on dark background
            .overlay(alignment: .bottom) {
                if showCopiedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Copied to Clipboard")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 5)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(album.collectionName ?? "Album")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadTracks()
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = errorMessage {
            ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if tracks.isEmpty {
            ContentUnavailableView("No Tracks Found", systemImage: "music.mic", description: Text("No tracks were found for this album."))
        } else {
            trackListView
        }
    }
    
    private var trackListView: some View {
        List{
            albumHeader
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 5)
                .listRowBackground(Color.clear)
   

            ForEach(tracks) { item in
                trackRowView(for: item)
            }
            
            albumFooter
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
    
    private func trackRowView(for item: iTunesSearchResult) -> some View {
        TrackRow(
            track: makeTrack(from: item),
            isDimmed: item.previewUrl == nil,
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
    }
    
    private var backgroundView: some View {
        ZStack {
            if let url = album.highResArtworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 35, opaque: false)
                } placeholder: {
                    Color.clear
                }
            }
            LinearGradient(
                colors: [.black.opacity(0.6), .black.opacity(0.2), .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    private var albumHeader: some View {
        VStack(spacing: 6) {
            AsyncImage(url: album.highResArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(uiColor: .systemGray5))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                            .font(.largeTitle)
                    }
            }
//            .frame(width: 300, height: 300)
            .cornerRadius(12)
            .shadow(radius: 15, y: 5)
            .padding(.bottom, 16)

            
            
            Text(album.collectionName ?? "Untitled Album")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineLimit(1)

            Text(album.artistName)
                .font(.body)
                .foregroundStyle(.pink)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .lineLimit(1)
            // Genre • Year
            Text(metadataString)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)

    }
    
    private var albumFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedReleaseDate)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Text("\(tracks.count) songs, \(formattedTotalDuration)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            if let copyright = album.copyright {
                Text(copyright)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties for UI
    
    private var metadataString: String {
        var parts: [String] = []
        if let genre = album.primaryGenreName, !genre.isEmpty {
            parts.append(genre)
        }
        if let releaseDate = album.releaseDate {
            let year = String(Calendar.current.component(.year, from: releaseDate))
            parts.append(year)
        }
        return parts.joined(separator: " • ")
    }
    
    private var formattedReleaseDate: String {
        guard let releaseDate = album.releaseDate else { return "Unknown Release Date" }
        return Self.fullDateFormatter.string(from: releaseDate)
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

    private func copyToClipboard(track: iTunesSearchResult) {
        let textToCopy = "\(track.artistName) - \(track.trackName ?? "Unknown Track")"
        UIPasteboard.general.string = textToCopy
        Haptics.notify(.success)
        
        withAnimation {
            showCopiedBanner = true
        }
        
        // Hide banner after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedBanner = false
            }
        }
    }
    
    private func loadTracks() async {
        guard let collectionId = album.collectionId else {
            errorMessage = "This album could not be found."
            isLoading = false
            return
        }
        
        isLoading = true
        do {
            let searchResults = try await APIService.shared.fetchTracksForAlbum(collectionId: collectionId)
            self.tracks = searchResults
            self.playableTracks = searchResults.compactMap(makeTrack)
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
            releaseDate: item.releaseDate.map { APIService.yearFormatter.string(from: $0) },
            customStreamURL: item.previewUrl
        )
    }
    
    // MARK: - Playback Logic
    
    private func playPreview(startingAt trackItem: iTunesSearchResult) {
        if let track = playableTracks.first(where: { $0.key == String(trackItem.trackId ?? 0) }) {
            playTracks(playableTracks, startingAt: track)
        }
    }
    
    private func playTracks(_ trackList: [Track], startingAt track: Track) {
        guard track.customStreamURL != nil else { return }
        Haptics.impact()
        
        if let index = trackList.firstIndex(where: { $0.key == track.key }) {
            player.setQueue(trackList, startAt: index)
        }
    }
}

