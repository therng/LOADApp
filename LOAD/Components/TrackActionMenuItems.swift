import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    var showSaveButton: Bool = false
    var onSave: (() -> Void)? = nil

    var body: some View {
            content
    }

    @ViewBuilder
    private var content: some View {
        MetadataHeader(track: track)
        Divider()
        FollowArtistButton(track: track)

        Button("Copy", systemImage: "doc.on.doc") {
            Haptics.selection()
            let textToCopy = "\(track.artist) - \(track.title)"
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
            message: Text("\(track.artist) - \(track.title)")
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
}

private struct MetadataHeader: View {
    let track: Track
    @State private var metadata: ITunesTrackMetadata?
    @State private var isLoading = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let copyright = copyrightText {
                        Text(copyright)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    if let metadataLine = metadataLine {
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
        .disabled(true)
        .task(id: track.id) { await loadMetadata() }
    }

    private var artworkView: some View {
        Group {
            if let url = metadata?.artworkURL ?? track.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(.rect(cornerRadius: 6))
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(uiColor: .systemGray5))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
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
        if let durationText = durationText {
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
    
    private func loadMetadata() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        if let cached = ITunesMetadataStorageService.shared.metadata(for: track) {
            metadata = cached
            return
        }
        metadata = await ITunesMetadataStorageService.shared.fetchMetadata(for: track)
    }
}

private struct FollowArtistButton: View {
    let track: Track
    
    var body: some View {
        let artists = track.artist.parseArtists()
        
        if artists.count > 1 {
            Menu {
                ForEach(artists, id: \.self) { artistName in
                    FollowButton(artistName: artistName)
                }
            } label: {
                Label("Follow Artist", systemImage: "person.crop.circle.badge.plus")
            }
        } else if let artistName = artists.first {
            FollowButton(artistName: artistName)
        }
    }
}


private struct FollowButton: View {
    let artistName: String
    @State private var isFollowed: Bool = false
    
    var body: some View {
        Button {
            Haptics.impact()
            Task {
                await ArtistStorageService.shared.toggleFollow(artistName: artistName)
                updateFollowState()
            }
        } label: {
            Label(isFollowed ? "Unfollow \(artistName)" : "Follow \(artistName)",
                  systemImage: isFollowed ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.plus")
        }
        .onAppear(perform: updateFollowState)
        .onChange(of: ArtistStorageService.shared.artists) { _, _ in
            updateFollowState()
        }
    }
    
    private func updateFollowState() {
        isFollowed = ArtistStorageService.shared.isArtistFollowed(artistName: artistName)
    }
}
