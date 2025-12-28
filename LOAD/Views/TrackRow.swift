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
          
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .blue : .primary)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(isCurrent ? .blue : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            HStack(spacing: 8) {
                Text(track.durationText)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? .blue : .primary)
                    .monospacedDigit()
            }
        }
    }
}

#Preview("TrackRow") {
    let sampleTracks: [Track] = [
        Track(artist: "Daft Punk", title: "Harder, Better, Faster, Stronger", duration: 224, key: "t1"),
        Track(artist: "Radiohead", title: "Karma Police", duration: 262, key: "t2"),
        Track(artist: "Nirvana", title: "Smells Like Teen Spirit", duration: 301, key: "t3"),
        Track(artist: "Beyoncé", title: "Halo", duration: 261, key: "t4"),
        Track(artist: "The Weeknd", title: "Blinding Lights", duration: 200, key: "t5")
    ]

    let player = AudioPlayerService.shared
    // Configure preview so the first sample track is playing
    player.setQueue(sampleTracks, startAt: sampleTracks[0])
    player.play(track: sampleTracks[0])

    return List {
        ForEach(sampleTracks) { track in
            TrackRow(track: track)
        }
    }
    .environmentObject(player)
}

