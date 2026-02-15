import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    var showSaveButton: Bool = false
    var onSaveSuccess: (() -> Void)? = nil
    @State private var isSaving = false
    @State private var followedArtists: [Artist] = []
    
    // Save Alert State
    @State private var showSaveAlert = false
    @State private var savedFileURL: URL?
    @State private var downloadProgress: Double = 0
    @State private var showProgress: Bool = false

    private var shareableText: String { "\(track.artist) - \(track.title)" }
   
    var body: some View {
        Group {
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
                if showProgress {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Save", systemImage: "arrow.down.circle") {
                    Haptics.impact(.medium)
                    Task {
                        await saveTrack()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: loadFollowedArtists)
        .onChange(of: ArtistStorageService.shared.artists) { _, newArtists in
            self.followedArtists = newArtists
        }
    }
    
    private func loadFollowedArtists() {
        self.followedArtists = ArtistStorageService.shared.artists
    }
    private func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalid)
            .joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func saveTrack() async {
        guard !isSaving else { return }
        isSaving = true
        downloadProgress = 0
        showProgress = true
        defer {
            isSaving = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                showProgress = false
                downloadProgress = 0
            }
        }

        // 1️⃣ Beatport lookup FIRST to get ID for filename
        var baseFilename = sanitizedFilename(track.title)
        
        do {
            let result = try await APIService.shared.beatportTrackID(
                artist: track.artist,
                title: track.title
            )
            baseFilename = "\(result.trackId)_\(baseFilename)"
        } catch {
#if DEBUG
            print("Beatport lookup failed, saving with original title:", error)
#endif
        }

        // 2️⃣ Save with the determined filename
        do {
            let savedURL = try await TrackStorageService.shared
                .saveTrack(track, customFilename: baseFilename)

            await MainActor.run {
                withAnimation(.linear(duration: 0.4)) {
                    downloadProgress = 1.0
                }
            }

            await MainActor.run {
                self.savedFileURL = savedURL
                self.showSaveAlert = true
                self.onSaveSuccess?()
            }

        } catch {
#if DEBUG
            print("Save error:", error)
#endif
        }
    }
    }

private struct FollowArtistButton: View {
    let track: Track
    @Binding var followedArtists: [Artist]

    private func parseArtists(from artistString: String) -> [String] {
        let separators = [" & ", " feat. ", " vs. ", " x "]
        var tempString = artistString.replacingOccurrences(of: " , ", with: ",")
        
        for separator in separators {
            tempString = tempString.replacingOccurrences(of: separator, with: ",", options: .caseInsensitive)
        }
        
        return tempString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        let artists = parseArtists(from: track.artist)
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
