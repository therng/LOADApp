import SwiftUI
struct TrackRow: View {
    let track: Track
    @EnvironmentObject var player: AudioPlayerService
    
    var isCurrent: Bool {
        player.currentTrack?.id == track.id
    }

    var isPlaying: Bool {
        isCurrent && player.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 12) {
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
                        .red, .blue, .cyan,
                        .pink, .yellow, .green,
                        .yellow, .purple, .pink
                    ]
                )

                if let coverURL = player.coverURL(for: track) {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "music.pages")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 35, height: 35)
                } else {
                    Image(systemName: "music.pages")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 35, height: 35)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPlaying {
                        Image(systemName: "waveform")
                            .foregroundStyle(.blue)
                            .symbolEffect(.variableColor.iterative.reversing)
                    }

                    Text(track.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(isCurrent ? .blue : .primary)
                }
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(isCurrent ? .blue : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            // Duration and play indicator
            HStack(spacing: 8) {
                Text(track.durationText)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? .blue : .primary)
                    .monospacedDigit()
            }
        }
        .task(id: track.id) {
            player.requestCoverIfNeeded(for: track)
        }
    }
}
