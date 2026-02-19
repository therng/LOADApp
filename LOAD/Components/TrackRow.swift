import SwiftUI

struct TrackRow: View {
    let track: Track
    var isDimmed: Bool = false
    
    // Feature Configuration
    var showSaveAction: Bool = false
    
    // Interaction closures
    var onPlay: (() -> Void)?
    var onCopy: (() -> Void)?
    
    @State private var showSavedBanner = false
    @State private var isSaving = false
    @Environment(AudioPlayerService.self) var player
    
    private var isCurrent: Bool {
        player.currentTrack?.id == track.id
    }
    
    private var isPlaying: Bool {
        isCurrent && player.isPlaying
    }
    
    private var nonCurrentPrimary: Color {
        isDimmed ? .secondary : .primary
    }
    
    private var nonCurrentSecondary: Color {
        isDimmed ? .secondary.opacity(0.6) : .secondary
    }
    
    private var currentProgress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isCurrent {
                    CircularProgressView(
                        progress: currentProgress,
                        isPlaying: isPlaying,
                        animationDuration: .linear
                    )
                }
            }
            // MARK: - Track Info
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .accentColor : nonCurrentPrimary)
                Text(track.artist)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .accentColor : nonCurrentSecondary)
            }
            
            Spacer()
            
            if isSaving {
                Image(systemName: "waveform")
                    .font(.system(size: 35, weight: .medium, design: .default))
                    .symbolEffect(.variableColor.iterative.hideInactiveLayers.nonReversing, options: .repeat(.continuous))
                    .foregroundStyle(Color.accentColor)
            } else if showSavedBanner || isSaved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium, design: .default))
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.byLayer), options: .nonRepeating))
                    .foregroundStyle(.green)
                    .onLongPressGesture {
                        if savedFileURL != nil {
                            showFileDetails = true
                        }
                    }
            } else {
                Text(track.durationText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(isCurrent ? .accentColor : nonCurrentSecondary)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .interactiveItem(onTap: onPlay, onLongPress: onCopy)
        .contextMenu {
            TrackActionMenuItems(
                track: track,
                showSaveButton: showSaveAction && !isSaved,
                onSave: {
                    Task {
                        await saveTrack()
                    }
                }
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if showSaveAction && !isSaved {
                Button {
                    Task { await saveTrack() }
                } label: {
                    Label("Save", systemImage: "arrow.down.circle")
                }
                .tint(.green)
            }
        }
        .task {
            checkIfSaved()
        }
        .sheet(isPresented: $showFileDetails) {
            if let url = savedFileURL {
                FileDetailView(fileURL: url, isPresented: $showFileDetails)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    @State private var isSaved = false
    @State private var savedFileURL: URL?
    @State private var showFileDetails = false

    private func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalid)
            .joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func checkIfSaved() {
        // Check standard filename (title)
        // Note: This won't detect files saved with Beatport ID prefix unless we store that mapping.
        // For now, we check the simple case to provide some feedback.
        let simpleFilename = sanitizedFilename(track.title)
        if TrackStorageService.shared.isTrackSaved(filename: simpleFilename) {
            isSaved = true
            savedFileURL = TrackStorageService.shared.fileURL(for: simpleFilename)
        }
        // Ideally we would also check possible Beatport-prefixed filenames if we could guess them,
        // but the ID is unknown without a fetch.
    }

    private func saveTrack() async {
        guard !isSaving && !isSaved else { return }
        isSaving = true
        defer { isSaving = false }

        // 1️⃣ Beatport lookup FIRST to get ID for filename
        var baseFilename = sanitizedFilename(track.title)
        
        do {
            let result = try await APIService.shared.beatportTrackID(
                title: track.title,
                artist: track.artist
            )
            baseFilename = "\(result.trackId)_\(baseFilename)"
        } catch {
            // Ignore error, use original filename
        }

        // 2️⃣ Save with the determined filename
        do {
            let url = try await TrackStorageService.shared
                .saveTrack(track, customFilename: baseFilename)
            
            savedFileURL = url

            // Success UI
            withAnimation {
                showSavedBanner = true
                isSaved = true
            }
            
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation {
                showSavedBanner = false
            }

        } catch {
            print("Save error: \(error)")
        }
    }
}

// MARK: - Interactive Item Modifier

struct InteractiveItemModifier: ViewModifier {
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.5, perform: {
                if let onLongPress {
                    Haptics.impact(.medium)
                    onLongPress()
                }
            }, onPressingChanged: { pressing in
                isPressed = pressing
            })
            .onTapGesture {
                if let onTap {
                    onTap()
                }
            }
    }
}

extension View {
    func interactiveItem(onTap: (() -> Void)? = nil, onLongPress: (() -> Void)? = nil) -> some View {
        modifier(InteractiveItemModifier(onTap: onTap, onLongPress: onLongPress))
    }
}
