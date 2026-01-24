import SwiftUI

struct MiniPlayerView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    @EnvironmentObject var player: AudioPlayerService
    @Binding var isFullPlayerPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Only show divider when expanded (above the tab bar)
            if placement == .expanded {
                Divider()
                    .overlay(Color.primary.opacity(0.05))
            }
            
            HStack(spacing: 12) {
                artworkView
                trackInfoView
                Spacer()
                playbackControlsView
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(.regularMaterial)
            .contentShape(Rectangle()) // Ensure the whole area is tappable
            .onTapGesture {
                isFullPlayerPresented = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private var artworkView: some View {
        Group {
            if let image = player.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var trackInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.currentTrack?.title ?? "Not Playing")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(player.currentTrack?.artist ?? "Select a song")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var playbackControlsView: some View {
        HStack(spacing: 20) {
            playPauseButton
            
            // Only show 'next' button when expanded
            if placement == .expanded {
                nextTrackButton
            }
        }
    }
    
    private var playPauseButton: some View {
        Button(action: player.togglePlayPause) {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
                .foregroundStyle(.primary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
    
    private var nextTrackButton: some View {
        Button(action: player.playNext) {
            Image(systemName: "forward.fill")
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService.shared)
}
