import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.openURL) var openURL
    
    // Local state to manage the slider scrubbing
    @State private var sliderValue: Double = 0.0
    @State private var isEditingSlider: Bool = false
    @State private var isShowingQueue: Bool = false

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
                        ShareLink(item: track.download) {
                            Label("Share Track", systemImage: "square.and.arrow.up")
                        }

                        Button(action: { player.enqueueNext(track) }) {
                            Label("Play Next", systemImage: "text.insert")
                        }
                        
                        Button(action: { player.addToQueue(track) }) {
                            Label("Add to Queue", systemImage: "text.badge.plus")
                        }
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
        .background(background)
        .sheet(isPresented: $isShowingQueue) {
            NavigationStack {
                QueueView()
                    .navigationTitle("Up Next")
            }
            .environmentObject(player)
        }
        .onChange(of: player.currentTime) { _, newTime in
            // Update slider position based on player's time, but only if the user isn't dragging it.
            if !isEditingSlider {
                sliderValue = newTime
            }
        }
        .onAppear {
            // Set initial slider position
            sliderValue = player.currentTime
        }
    }

    // MARK: - Subviews

    private var background: some View {
        ZStack {
            if let artwork = player.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode:.fill)
                    .blur(radius:40, opaque: true)
                    
            } else {
                // Use the calculated dominant color as a fallback
                Rectangle()
                    .fill(player.dominantColor ?? .black)
            }
        }
        .ignoresSafeArea()
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
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .multilineTextAlignment(.center)
            
            Text(player.currentTrack?.artist ?? " ")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(player.currentTrack?.releaseDate ?? " ")
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
            Button(action: player.playPrevious) {
                Image(systemName: "backward.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
            }
            .disabled(player.currentTrack == nil)

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
            }
            .disabled(player.currentTrack == nil)

            Button(action: player.playNext) {
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
        .preferredColorScheme(.dark)
}

