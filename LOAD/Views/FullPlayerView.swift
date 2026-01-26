import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    // Local state to manage the slider scrubbing
    @State private var sliderValue: Double = 0.0
    @State private var isEditingSlider: Bool = false
    @State private var isShowingQueue: Bool = false
    @State private var safariURLItem: SafariURLItem?
    @State private var safariDetent: PresentationDetent = .medium
    
    // Beatport Search State
    @State private var showBeatportAlert = false
    @State private var beatportArtist = ""
    @State private var beatportTitle = ""
    @State private var beatportMix = ""
    
    var body: some View {
            VStack(spacing: 0) {
                // A handle to indicate the sheet can be dismissed
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.vertical, 10)
                
                // Album Artwork
                artwork
                    .padding(.vertical, 30)
                
                // Track Information
                trackDetails
                
                // Scrubber / Progress Bar
                scrubber
                    .padding(.vertical, 20)
                
                // Playback Controls
                controls
                
                // Secondary Controls
                HStack (alignment: .center, spacing: 40){
                    Menu {
                        if let track = player.currentTrack {
                            TrackActionMenuItems(
                                track: track,
                                onSave: { url in
                                    safariDetent = .medium
                                    safariURLItem = SafariURLItem(url: url)
                                },
                                onGoToArtist: nil,
                                onSearchBeatport: { artist, title, mix in
                                    self.beatportArtist = artist
                                    self.beatportTitle = title
                                    self.beatportMix = mix
                                    self.showBeatportAlert = true
                                },
                                player: player
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .frame(height: 28)
                            .frame(width: 44, height: 44) // Standard tap target
                    }
                    .disabled(player.currentTrack == nil)
                    
                    
                    AirPlayButtonView()
                        .font(.largeTitle)
                        .frame(height: 28)
                        .frame(width: 44, height: 44)
                    
                    Button(action: {
                        Haptics.impact()
                        isShowingQueue = true
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .frame(height: 28)
                            .frame(width: 44, height: 44) // Standard tap target
                    }
                    .disabled(player.currentTrack == nil)
                }
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .padding(.top,20)
            }
            .padding(.horizontal,35)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PlayerBackgroundView())
            .foregroundStyle(.primary)
            // Attach the Beatport Alert here
            .beatportSearchAlert(isPresented: $showBeatportAlert, artist: $beatportArtist, title: $beatportTitle, mix: $beatportMix)
            .sheet(item: $safariURLItem) { item in
                SafariView(url: item.url)
            }
            .sheet(isPresented: $isShowingQueue) {
                NavigationStack {
                    QueueView()
                        .navigationTitle("Up Next")
                }
                .environmentObject(player)
            }
            .presentationDetents([.medium, .large], selection: $safariDetent)
            .presentationDragIndicator(.visible)
            .onChange(of: player.currentTime) { _, newTime in
                // Update slider position based on player's time, but only if the user isn't dragging it.
                if !isEditingSlider && player.duration > 0 {
                    sliderValue = min(newTime, player.duration)
                }
            }
            .onAppear {
                // Set initial slider position
                if player.duration > 0 {
                    sliderValue = min(player.currentTime, player.duration)
                } else {
                    sliderValue = 0
                }
            }
            .preferredColorScheme(.dark)
        }
        
    private var artwork: some View {
            Group {
                if let artwork = player.artworkImage {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        }
                }
            }
        }
        
        private var trackDetails: some View {
            VStack(spacing: 8) {
                Text(player.currentTrack?.title ?? "Not Playing")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(player.currentTrack?.artist ?? " ")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                
                Text(player.currentTrack?.releaseDate ?? " ")
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
        }
        
        private var scrubber: some View {
            VStack(spacing: 4) {
                Slider(
                    value: $sliderValue,
                    in: 0...(player.duration > 0 ? player.duration : 1),
                    onEditingChanged: { isEditing in
                        isEditingSlider = isEditing
                        if isEditing {
                            player.startScrubbing()
                        } else {
                            player.endScrubbing(at: sliderValue)
                        }
                    }
                )
                .disabled(player.duration <= 0) // Disable slider if duration is unknown
                
                HStack {
                    Text((isEditingSlider ? sliderValue : player.currentTime).formattedAsTime())
                    Spacer()
                    Text(player.duration.formattedAsTime())
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
        }
        
        private var controls: some View {
            HStack(spacing: 40) {
                Button(action: {
                    Haptics.selection()
                    player.playPrevious()
                }) {
                    Image(systemName: "backward.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                }
                .disabled(player.currentTrack == nil)
                
                Button(action: {
                    Haptics.selection()
                    player.togglePlayPause()
                }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
                .disabled(player.currentTrack == nil)
                
                Button(action: {
                    Haptics.selection()
                    player.playNext()
                }) {
                    Image(systemName: "forward.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                }
                .disabled(player.currentTrack == nil)
            }
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
            .padding(.vertical, 20)
        }
    }


// MARK: - Time Formatter Helper

private extension TimeInterval {
    func formattedAsTime() -> String {
        guard self >= 0, self.isFinite else { return "0:00" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let player: AudioPlayerService = {
        let service = AudioPlayerService()
        let track = Track(
            artist: "craig connelly",
            title: "Other side of the world",
            duration: 320,
            key: "preview-track",
            releaseDate: "2023"
        )
        // By using `setQueue`, the service's `currentTrack` will be updated,
        // allowing the preview to display the track's metadata.
        // Full playback state is not available due to service limitations.
        service.setQueue([track])
        return service
    }()

    return FullPlayerView()
        .environmentObject(player)
}

