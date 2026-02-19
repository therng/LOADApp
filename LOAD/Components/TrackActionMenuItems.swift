import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    var showSaveButton: Bool = false
    var onSave: (() -> Void)? = nil
    
    @State private var followedArtists: [Artist] = []
    @State private var isLoadingMetadata = false
    @State private var metadata: ITunesTrackMetadata?

    private var shareableText: String { "\(track.artist) - \(track.title)" }
   
    var body: some View {
        Group {
            Button(action: {}) {
                metadataHeader
            }
            .disabled(true)

            Divider()

            FollowArtistButton(track: track, followedArtists: $followedArtists)

            Button("Copy", systemImage: "doc.on.doc") {
                Haptics.selection()
                let textToCopy = shareableText
                #if canImport(UIKit)
                UIPasteboard.general.string = textToCopy
                #elseif canImport(AppKit)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                #endif
            }

            ShareLink(
                item: track.download,
                subject: Text(track.title),
                message: Text(shareableText)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()

            if showSaveButton {
                Button("Save", systemImage: "arrow.down.circle") {
                    Haptics.impact(.medium)
                    onSave?()
                }
            }
        }
        .onAppear(perform: loadFollowedArtists)
        .task { await loadMetadata() }
        .onChange(of: ArtistStorageService.shared.artists) { _, newArtists in
            self.followedArtists = newArtists
        }
    }
    
    private var artworkURL: URL? {
        metadata?.artworkURL ?? track.artworkURL
    }

    private var metadataLine: String? {
        var parts: [String] = []
        if let collectionName = metadata?.collectionName ?? track.collectionName, !collectionName.isEmpty {
            parts.append(collectionName)
        }
        if let releaseYear = metadata?.releaseDate ?? track.releaseDate, !releaseYear.isEmpty {
            parts.append(releaseYear)
        }
        if let genre = metadata?.genre ?? track.genre, !genre.isEmpty {
            parts.append(genre)
        }
        if let durationText {
            parts.append(durationText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var durationText: String? {
        let duration = metadata?.duration ?? track.duration
        guard duration > 0 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(duration))
    }

    private var copyrightText: String? {
        let value = metadata?.copyright ?? track.copyright
        return (value ?? "").isEmpty ? nil : value
    }

    private var metadataHeader: some View {
        HStack(spacing: 12) {
            artworkView
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // Line 2: Artist
                Text(track.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Line 3: Copyright
                if let copyright = copyrightText {
                    Text(copyright)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
                
                // Line 4: Album + Year + Genre + Duration
                if let metadataLine {
                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
           Text(track.durationText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artworkView: some View {
        Group {
            if let url = artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .cornerRadius(6)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(uiColor: .systemGray5))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }

    private func loadMetadata() async {
        guard !isLoadingMetadata else { return }
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }

        if let cached = ITunesMetadataStorageService.shared.metadata(for: track) {
            metadata = cached
            return
        }

        metadata = await ITunesMetadataStorageService.shared.fetchMetadata(for: track)
    }

    private func loadFollowedArtists() {
        self.followedArtists = ArtistStorageService.shared.artists
    }
}

private struct FollowArtistButton: View {
    let track: Track
    @Binding var followedArtists: [Artist]

    var body: some View {
        let artists = track.artist.parseArtists()
        let onToggle: (String) -> Void = { artistName in
            Task {
                await ArtistStorageService.shared.toggleFollow(artistName: artistName)
                self.followedArtists = ArtistStorageService.shared.artists
            }
        }
        
        if artists.count > 1 {
            Menu {
                ForEach(artists, id: \.self) { artistName in
                    FollowButton(artistName: artistName, followedArtists: $followedArtists, onToggle: onToggle)
                }
            } label: {
                Label("Follow Artist", systemImage: "person.crop.circle.badge.plus")
            }
        } else if let artistName = artists.first {
            FollowButton(artistName: artistName, followedArtists: $followedArtists, onToggle: onToggle)
        }
    }
}


private struct FollowButton: View {
    let artistName: String
    @Binding var followedArtists: [Artist]
    let onToggle: (String) -> Void
    
    private var isFollowed: Bool {
        followedArtists.contains { $0.artistName.lowercased() == artistName.lowercased() }
    }
    
    private var buttonLabel: String {
        isFollowed ? "Unfollow \(artistName)" : "Follow \(artistName)"
    }
    
    private var buttonImage: String {
        isFollowed ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.plus"
    }
    
    var body: some View {
        Button(buttonLabel, systemImage: buttonImage) {
            Haptics.impact()
            onToggle(artistName)
        }
    }
}
