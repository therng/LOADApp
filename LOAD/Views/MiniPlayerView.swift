import SwiftUI

struct MiniPlayerView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var tabViewBottomAccessoryPlacement
    @EnvironmentObject var player: AudioPlayerService
    @Binding var isFullPlayerPresented: Bool

    var body: some View {
        switch tabViewBottomAccessoryPlacement {
        case .expanded:
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    waveformView
                    titleView
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                controlsView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .onTapGesture {
                Haptics.selection()
                isFullPlayerPresented = true
            }
        default:
            HStack(spacing:12){
                Image(systemName: "waveform")
                    .scaleEffect(1)
                    .symbolEffect(.variableColor.cumulative.reversing, options: .repeating.speed(1.5))
                    .foregroundStyle(player.isPlaying ? .blue : .primary)
               titleView
                    .scaleEffect(1)
                Button(action: player.togglePlayPause) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                }
            
                .padding(.horizontal,20)
                .padding(.vertical, 10)
                .onTapGesture {
                    Haptics.selection()
                    isFullPlayerPresented = true
                }
            }
        }
    
    @ViewBuilder
    private var titleView: some View {
        if let track = player.currentTrack {
            MarqueeText(
                text: track.title,
                font: .body,
                color: .primary,
                isActive: true,
                speed: 28,
                spacing: 24,
                alignment: .leading
            )
        } else {
            Text("Not Playing")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var waveformView: some View {
        Image(systemName: "waveform")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.blue, .purple, .pink)
            .font(.headline)
            .symbolEffect(.bounce, options: .repeating.speed(1))
            .symbolEffect(.variableColor.cumulative.reversing, options: .repeating.speed(0.8))
            .frame(width: 40, height: 40)
    }

    private var controlsView: some View {
        HStack(spacing: 16) {
            Button(action: {
                Haptics.impact()
                player.togglePlayPause()
            }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
            }

            Button(action: {
                Haptics.impact()
                player.playNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22))
            }
        }
    }
}
