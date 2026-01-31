import SwiftUI

struct AlbumTrackRowView: View {
    let item: iTunesSearchResult
    let track: Track
    let onPlay: () -> Void
    let onCopy: () -> Void
    
    @EnvironmentObject var player: AudioPlayerService
    @State private var isPressing = false
    
    var body: some View {
        HStack(spacing: 4) {
            let isCurrent = player.currentTrack?.key == String(item.trackId ?? 0)
            
            if isCurrent {
                PreviewProgressView(
                    progress: player.currentTime / (player.duration > 0 ? player.duration : 30.0),
                    isPlaying: player.isPlaying
                )
                .frame(width: 25, height: 25)
            } else {
                Text("\(item.trackNumber ?? 0)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 25, alignment: .center)
            }
            
            TrackRow(track: track, isDimmed: item.previewUrl == nil)
        }
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5, perform: {
            onCopy()
        }, onPressingChanged: { pressing in
            isPressing = pressing
        })
        .onTapGesture {
            onPlay()
        }
    }
}

struct PreviewProgressView: View {
    let progress: Double
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
        }
    }
}
