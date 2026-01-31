import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    let onSave: (URL) -> Void
    let onGoToArtist: ((String) -> Void)?
    // เพิ่ม callback สำหรับส่งข้อมูลกลับไปหน้าหลัก
    let onSearchBeatport: ((_ artist: String, _ title: String, _ mix: String) -> Void)?
    let player: AudioPlayerService

    @ObservedObject private var storage = ArtistStorageService.shared
    @State private var followedArtists: [Artist] = []

    private var shareableText: String { "\(track.artist) - \(track.title)" }
   
    var body: some View {
        // Group is used to attach the .alert modifier to all the menu items.
        Group {
            Button("Play Next", systemImage: "text.insert") {
                Haptics.impact()
                player.enqueueNext(track)
            }

            Button("Add to Queue", systemImage: "text.badge.plus") {
                Haptics.selection()
                player.addToQueue(track)
            }
            
            Divider()

            if let onGoToArtist {
                Button("Go to Artist", systemImage: "music.mic") {
                    Haptics.impact()
                    onGoToArtist(track.artist)
                }
            }

            FollowArtistButton(track: track, followedArtists: $followedArtists)
            
            if let onSearchBeatport {
                Button("Beatport", systemImage: "magnifyingglass.circle") {
                    Haptics.impact()
                    // Parsing logic stays here to prepare the data
                    let parsed = track.title.parseTitleAndMix()
                    // Send data to parent view to show alert
                    onSearchBeatport(track.artist, parsed.title, parsed.mix ?? "")
                }
            }


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

            Button("Save", systemImage: "arrow.down.circle") {
                Haptics.impact(.medium)
                onSave(track.download)
            }
        }
        .onAppear {
            self.followedArtists = storage.artists
        }
        .onReceive(storage.$artists) { artists in
            self.followedArtists = artists
        }
    }
}

// MARK: - Reusable Search Sheet Logic

struct BeatportSearchModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var artistInput: String
    @Binding var titleInput: String
    @Binding var mixInput: String
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                BeatportSearchSheet(
                    artistInput: $artistInput,
                    titleInput: $titleInput,
                    mixInput: $mixInput
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

private struct BeatportSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var artistInput: String
    @Binding var titleInput: String
    @Binding var mixInput: String
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        TextField("Artist Name", text: $artistInput)
                            .autocapitalization(.none)
                            .textContentType(.name)
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.pink)
                    }

                    LabeledContent {
                        TextField("Track Title", text: $titleInput)
                            .autocapitalization(.words)
                    } label: {
                        Image(systemName: "music.note")
                            .foregroundStyle(.blue)
                    }

                    LabeledContent {
                        TextField("Mix Version", text: $mixInput)
                            .autocapitalization(.words)
                    } label: {
                        Image(systemName: "slider.horizontal.2.square")
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("Edit details to refine the Beatport search.")
                    }
                }
                
                Section {
                    Button(action: search) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 5)
                            }
                            Text(isLoading ? "Searching..." : "Search Beatport ID")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading)
                    .listRowBackground(Color.blue)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Search Beatport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func search() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let trimmedMix = mixInput.trimmingCharacters(in: .whitespaces)
                // Pass parameters directly; APIService handles them without re-parsing if mix is provided.
                let result = try await APIService.shared.beatportTrackID(
                    artist: artistInput,
                    title: titleInput,
                    mix: trimmedMix
                )
                let idString = String(result)
                
                await MainActor.run {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = idString
                    #elseif canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(idString, forType: .string)
                    #endif
                    
                    Haptics.notify(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    Haptics.notify(.error)
                    errorMessage = "Track ID not found. Please try refining the details."
                    isLoading = false
                }
            }
        }
    }
}
// MARK: - Reusable Follow Artist Button

private struct FollowArtistButton: View {
    let track: Track
    @Binding var followedArtists: [Artist]
    @ObservedObject private var storage = ArtistStorageService.shared

    private func parseArtists(from artistString: String) -> [String] {
        let separators = [" , ",", & "," feat. "," vs. "," Feat. "," Vs. "," x "]
        var artists = [artistString]
        
        for separator in separators {
            artists = artists.flatMap { $0.components(separatedBy: separator) }
        }
        
        return artists.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        let artists = parseArtists(from: track.artist)
        let onToggle: (String) -> Void = { artistName in
            Task {
                await storage.toggleFollow(artistName: artistName)
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

extension View {
    func beatportSearchAlert(isPresented: Binding<Bool>, artist: Binding<String>, title: Binding<String>, mix: Binding<String>) -> some View {
        self.modifier(BeatportSearchModifier(isPresented: isPresented, artistInput: artist, titleInput: title, mixInput: mix))
    }
}
