import SwiftUI
struct TrackRow: View {
    let track: Track
    var isDimmed: Bool = false
    @EnvironmentObject var player: AudioPlayerService
    
    var isCurrent: Bool {
        player.currentTrack?.id == track.id
    }

    var isPlaying: Bool {
        isCurrent && player.isPlaying
    }

    private var nonCurrentPrimary: Color {
        isDimmed ? .secondary : .primary
    }

    private var nonCurrentSecondary: Color {
        isDimmed ? .secondary : .secondary
    }
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isPlaying ? .blue : nonCurrentPrimary)
                Text(track.artist)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isPlaying ? .blue : nonCurrentSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(track.durationText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(isPlaying ? .blue : nonCurrentPrimary)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
    }
}
