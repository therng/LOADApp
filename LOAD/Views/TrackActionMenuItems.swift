import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    let onSave: (URL) -> Void
    let onGoToArtist: ((String) -> Void)?
    // เพิ่ม callback สำหรับส่งข้อมูลกลับไปหน้าหลัก
    let onSearchBeatport: ((_ artist: String, _ title: String, _ mix: String) -> Void)?
    let player: AudioPlayerService

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
                let fullTitle: String
                let trimmedMix = mixInput.trimmingCharacters(in: .whitespaces)
                if trimmedMix.isEmpty {
                    fullTitle = titleInput
                } else {
                    fullTitle = "\(titleInput) (\(trimmedMix))"
                }
                
                let id = try await APIService.shared.BeatportTrackID(artist: artistInput, title: fullTitle)
                let idString = String(id)
                
                await MainActor.run {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = idString
                    #elseif canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(idString, forType: .string)
                    #endif
                    
                    NotificationCenter.default.post(name: .showBanner, object: "\(idString) copied")
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

extension View {
    func beatportSearchAlert(isPresented: Binding<Bool>, artist: Binding<String>, title: Binding<String>, mix: Binding<String>) -> some View {
        self.modifier(BeatportSearchModifier(isPresented: isPresented, artistInput: artist, titleInput: title, mixInput: mix))
    }
}
