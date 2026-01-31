import SwiftUI
import Foundation

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.openURL) var openURL
    
    // Local state to manage the slider scrubbing
    @State private var sliderValue: Double = 0.0
    @State private var isEditingSlider: Bool = false
    @State private var isShowingQueue: Bool = false
    @State private var safariURLItem: SafariURLItem?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var artistToShow: ArtistDisplayItem?
    @State private var showBeatportAlert = false
    @State private var beatportArtist: String = ""
    @State private var beatportTitle: String = ""
    @State private var beatportMix: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A handle to indicate the sheet can be dismissed
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.vertical, 10)
                
                // Album Artwork
                artwork
                    .padding(.vertical, 20)
                
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
                            TrackActionMenuItems(track: track, onSave: { url in
                                safariDetent = .medium
                                safariURLItem = SafariURLItem(url: url)
                            }, onGoToArtist: { artistName in
                                Task {
                                    if let artist = try? await APIService.shared.searchForArtist(artistName),
                                       let artistId = artist.artistId {
                                        self.artistToShow = ArtistDisplayItem(id: artistId, name: artist.artistName)
                                    }
                                }
                            },
                                onSearchBeatport: { artist, title, mix in
                                self.beatportArtist = artist
                                self.beatportTitle = title
                                self.beatportMix = mix
                                self.showBeatportAlert = true
                            },
                            player: player)
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
            .sheet(isPresented: $isShowingQueue) {
                NavigationStack {
                    QueueView()
                        .navigationTitle("Up Next")
                }
                .environmentObject(player)
            }
            .sheet(item: $safariURLItem) { item in
                SafariView(url: item.url)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
            }
            .beatportSearchAlert(isPresented: $showBeatportAlert, artist: $beatportArtist, title: $beatportTitle, mix: $beatportMix)
            .navigationDestination(item: $artistToShow) { artistItem in
                ArtistDetailView(artistId: artistItem.id, artistName: artistItem.name)
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
            .preferredColorScheme(.dark)
        }
    }
        
    private var artwork: some View {
        ArtworkView(
            image: player.artworkImage,
            cornerRadius: 12,
            shadowRadius: 10,
            iconSize: 80
        )
        .aspectRatio(1, contentMode: .fit)
    }
        
    private var trackDetails: some View {
            VStack(spacing: 5) {
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
                
                HStack {
                    Text((isEditingSlider ? sliderValue : player.currentTime).durationText())
                    Spacer()
                    Text(player.duration.durationText())
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
        }
        
        private var controls: some View {
            HStack(spacing: 30) {
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
                        .frame(height: 30)
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

// MARK: - Helper Structs

private struct SafariURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

// Wrapper struct to make artist name identifiable for navigation
private struct ArtistDisplayItem: Identifiable, Hashable {
    let id: Int
    let name: String
}

// MARK: - TimeInterval Extension
extension TimeInterval {
    func durationText() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        if self >= 3600 {
            formatter.allowedUnits = [.hour, .minute, .second]
        } else {
            formatter.allowedUnits = [.minute, .second]
        }

        return formatter.string(from: self) ?? "0:00"
    }
}

