import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @EnvironmentObject var player: AudioPlayerService
    @State private var tracks: [iTunesSearchResult] = []
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
                            .foregroundColor(Color(.green))
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
            .navigationTitle(album.collectionName)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadTracks()
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if isLoading && tracks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !tracks.isEmpty {
            trackListView
        } else if let message = errorMessage {
            ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(message))
        } else {
            ContentUnavailableView("No Tracks Found", systemImage: "music.mic", description: Text("No tracks were found for this album."))
        }
    }
    
    private var trackListView: some View {
        List {
            albumHeader
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
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
        .refreshable {
            await loadTracks()
        }
    }
    
    private func trackRowView(for item: iTunesSearchResult) -> some View {
        AlbumTrackRowView(
            item: item,
            track: makeTrack(from: item),
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
                        .blur(radius: 40)
                        .overlay(Color.black.opacity(0.05))
                } placeholder: {
                    Color.clear
                }
            } else {
                Color(uiColor: .systemBackground)
            }
        }
        .ignoresSafeArea()
    }
    
    private var albumHeader: some View {
        VStack(spacing: 6) {
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
            .frame(width: 240, height: 240)
            .cornerRadius(12)
            .shadow(radius: 15, y: 5)
            .padding(.bottom, 16)
            
            Text(album.collectionName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(album.artistName)
                .font(.title3)
                .foregroundStyle(.pink)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Genre • Year
            Text(metadataString)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: playAlbum) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                    .font(.headline)
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .secondarySystemFill))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(tracks.isEmpty)

                Button(action: shuffleAlbum) {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Shuffle")
                    }
                    .font(.headline)
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .secondarySystemFill))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(tracks.isEmpty)
            }
            .padding(.top, 20)
            .padding(.horizontal)
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
        let year = String(Calendar.current.component(.year, from: album.releaseDate))
        parts.append(year)
        return parts.joined(separator: " • ")
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
    
    // MARK: - Playback Logic
    
    private func playAlbum() {
        if let first = tracks.first {
            playPreview(startingAt: first)
        }
    }
    
    private func shuffleAlbum() {
        let shuffled = tracks.shuffled()
        if let first = shuffled.first {
            playTracks(shuffled, startingAt: first)
        }
    }
    
    private func playPreview(startingAt track: iTunesSearchResult) {
        playTracks(tracks, startingAt: track)
    }
    
    private func playTracks(_ trackList: [iTunesSearchResult], startingAt track: iTunesSearchResult) {
        guard track.previewUrl != nil else { return }
        
        let convertedTracks = trackList.compactMap { item -> Track? in
            guard item.previewUrl != nil else { return nil }
            return makeTrack(from: item)
        }
        
        if let index = convertedTracks.firstIndex(where: { $0.key == String(track.trackId ?? 0) }) {
            player.setQueue(convertedTracks, startAt: index)
        }
    }
}

// Subview to handle row state independently
private struct AlbumTrackRowView: View {
    let item: iTunesSearchResult
    let track: Track
    let onPlay: () -> Void
    let onCopy: () -> Void
    
    @EnvironmentObject var player: AudioPlayerService
    @State private var isPressing = false
    
    var body: some View {
        HStack(spacing: 4) {
            let isCurrent = player.currentTrack?.key == String(item.trackId ?? 0)
            
            if isCurrent {
                PreviewProgressView(
                    progress: player.currentTime / (player.duration > 0 ? player.duration : 30.0),
                    isPlaying: player.isPlaying
                )
                .frame(width: 25, height: 25)
            } else {
                Text("\(item.trackNumber ?? 0)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 25, alignment: .center)
            }
            
            TrackRow(track: track, isDimmed: item.previewUrl == nil)
        }
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5, perform: {
            onCopy()
        }, onPressingChanged: { pressing in
            isPressing = pressing
        })
        .onTapGesture {
            onPlay()
        }
    }
}

struct PreviewProgressView: View {
    let progress: Double
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
        }
    }
}
