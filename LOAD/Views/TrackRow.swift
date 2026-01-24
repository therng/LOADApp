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
                        .foregroundColor(isPlaying ? .blue: nonCurrentPrimary)
                    Text(track.artist)
                        .font(.system(size: 16, weight: .light, design: .rounded))
                        .lineLimit(1)
                        .foregroundColor(isPlaying ? .blue: nonCurrentSecondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    Text(track.releaseDate ?? "")
                        .font(.system(size: 11, weight: .light, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(track.durationText)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(isPlaying ? .blue: nonCurrentPrimary)
                }
        }
        .padding(.horizontal, 5)
        .padding(.vertical,3)
    }
}

#Preview("TrackRow") {
    let sampleTracks: [Track] = [
        Track(artist: "Daft Punk", title: "Harder, Better, Faster, Stronger", duration: 224, key: "t1",releaseDate:"2013"),
        Track(artist: "Radiohead", title: "Karma Police", duration: 262, key: "t2"),
        Track(artist: "Nirvana", title: "Smells Like Teen Spirit", duration: 301, key: "t3"),
        Track(artist: "Beyoncé", title: "Halo", duration: 261, key: "t4"),
        Track(artist: "The Weeknd", title: "Blinding Lights", duration: 200, key: "t5")
    ]

    let player = AudioPlayerService.shared
    // Configure preview so the first sample track is playing
    player.setQueue(sampleTracks, startAt: 0)

    return List {
        ForEach(sampleTracks) { track in
            TrackRow(track: track)
        }
    }
    .environmentObject(player)
}
