import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Binding var isFullPlayerPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Tiny Progress Bar
            if let duration = player.currentTrack?.duration, duration > 0 {
                ProgressView(value: player.currentTime, total: Double(duration))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(height: 2)
            }
            
            HStack(spacing: 12) {
                // Artwork
                if let artwork = player.artworkImage {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(player.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 16) {
                    Button {
                        player.togglePlayPause()
                        Haptics.selection()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        player.playNext()
                        Haptics.selection()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .onTapGesture {
            isFullPlayerPresented = true
        }
    }
}

#Preview {
    MiniPlayerView(isFullPlayerPresented: .constant(false))
        .environmentObject(AudioPlayerService.shared)
        .previewLayout(.sizeThatFits)
}
