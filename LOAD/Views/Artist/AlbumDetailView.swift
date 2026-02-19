import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @Environment(AudioPlayerService.self) var player
    @Environment(AppNavigationManager.self) var navigationManager
    @Environment(\.colorScheme) private var colorScheme
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
    
    private var backgroundView: some View {
        GeometryReader { proxy in
            ZStack {
                if let url = album.artworkURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .overlay(overlayGradient)
                            .blur(radius: 30)
                    } placeholder: {
                        Color(.systemBackground)
                    }
                } else {
                    Color(.systemBackground)
                }

                // Subtle bottom overlay to improve contrast for content near the bottom
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.25))
                        .frame(height: 120)
                        .blur(radius: 10)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var overlayGradient: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: colorScheme == .dark ? Color.black.opacity(0.55) : Color.white.opacity(0.35), location: 0.0),
                .init(color: Color.clear, location: 0.5),
                .init(color: colorScheme == .dark ? Color.black.opacity(0.65) : Color.white.opacity(0.45), location: 1.0),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var albumHeader: some View {
        VStack(spacing: 6) {
            AsyncImage(url: album.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(uiColor: .systemGray5))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .font(.largeTitle)
                    }
            }
//            .frame(width: 300, height: 300)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 15, y: 5)
            .padding(.bottom, 16)

            
            
            Text(album.collectionName)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineLimit(1)

            Text(album.artistName)
                .font(.body)
                .foregroundStyle(Color.accent)
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
            
            if !albumCopyright.isEmpty {
                Text(albumCopyright)
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
        if !album.primaryGenreName.isEmpty {
            parts.append(album.primaryGenreName)
        }
        let year = String(Calendar.current.component(.year, from: album.releaseDate))
        parts.append(year)
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }
    
    private var formattedReleaseDate: String {
        Self.fullDateFormatter.string(from: album.releaseDate)
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

    private var albumCopyright: String {
        album.copyright
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
        isLoading = true
        do {
            let searchResults = try await APIService.shared.fetchTracksForAlbum(collectionId: album.collectionId)
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
            localURL: nil,
            artworkURL: item.artworkURL,
            releaseDate: APIService.yearFormatter.string(from: item.releaseDate),
            customStreamURL: item.previewURL
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

