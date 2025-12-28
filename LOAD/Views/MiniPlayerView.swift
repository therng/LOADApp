import SwiftUI
    
struct MiniPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Binding var isFullPlayerPresented: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .orange, .pink, .purple,
                        .red, .pink, .indigo,
                        .purple, .blue, .cyan
                    ]
                )
                
                if let coverURL = player.currentCoverURL {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.8))
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 4)
            if let track = player.currentTrack {
                Text(track.title)
                    .font(.body)
                    .fontWeight(.regular)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
            }
            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFullPlayerPresented = true
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 12)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .background(.ultraThinMaterial)
        .task(id: player.currentTrack?.id) {
            if let track = player.currentTrack {
                player.requestCoverIfNeeded(for: track)
            }
        }
    }
}
