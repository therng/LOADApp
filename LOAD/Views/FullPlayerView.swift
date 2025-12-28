import SwiftUI
import Combine

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var isTitleMarqueeActive = false


    var body: some View {
        ZStack {
         
            GeometryReader { proxy in
                VStack(spacing: 20) {
                    headerMenu
                    Spacer(minLength: 8)
                    ArtworkView(size: min(proxy.size.width * 0.78, 320))

                    if let track = player.currentTrack {
                        TrackInfoView(
                            title: track.title,
                            artist: track.artist,
                            isMarqueeActive: $isTitleMarqueeActive,
                            titleFont: titleFont,
                            artistFont: artistFont
                        )
                    }

                    PlaybackProgressView(progress: player.progress, onSeek: player.seek)
                    PlaybackControlsView()
                    AirPlayRoutePicker()
                        .frame(width: 45, height: 45)
                        .accessibilityLabel("AirPlay")

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]), startPoint: .top, endPoint: .bottom))
        .sheet(isPresented: Binding(get: { safariURL != nil }, set: { if !$0 { safariURL = nil } })) {
            if let safariURL {
                SafariView(url: safariURL)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
                
            }
        }
  
        .onChange(of: player.currentTrack?.id) { _, _ in
            isTitleMarqueeActive = false
        }
    }

    private var headerMenu: some View {
        NowPlayingHeaderView(
            track: player.currentTrack,
            onMenuAction: { safariURL = $0 }
        )
    }

    private var titleFont: Font {
        .title2.weight(.bold)
    }

    private var artistFont: Font {
        .title3
    }

    private func ArtworkView(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)

            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.primary.opacity(0.15), radius: 20, y: 10)
        .accessibilityLabel("Album artwork")
    }

    private func PlaybackControlsView() -> some View {
        HStack(spacing: 40) {
            Button(action: player.playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
            }

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .symbolEffect(.bounce, value: player.isPlaying)
            }

            Button(action: player.playNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Subviews

private struct PlaybackProgressView: View {
    @ObservedObject var progress: AudioPlayerService.PlaybackProgress
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(get: { progress.currentTime }, set: onSeek),
                in: 0...max(progress.duration, 1)
            )
            .tint(.accentColor)

            HStack {
                Text(progress.currentTime.mmss)
                Spacer()
                Text(progress.duration.mmss)
            }
            .frame(maxWidth: .infinity)
            .font(.caption)
            .foregroundStyle(.primary.opacity(0.7))
            .monospacedDigit()
        }
    }
}

private struct NowPlayingHeaderView: View {
    let track: Track?
    let onMenuAction: (URL) -> Void

    var body: some View {
        HStack {
            Text("Now Playing")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary.opacity(0.8))

            Spacer()

            Menu {
                if let track = track {
                    TrackActionMenuItems(track: track, onSave: onMenuAction)
                } else {
                    Button("No Track", systemImage: "music.note") {}
                        .disabled(true)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrackInfoView: View {
    let title: String
    let artist: String
    @Binding var isMarqueeActive: Bool
    let titleFont: Font
    let artistFont: Font

    var body: some View {
        VStack(spacing: 8) {
            MarqueeText(
                text: title,
                font: titleFont,
                color: .primary,
                isActive: isMarqueeActive,
                speed: 32,
                spacing: 32,
                alignment: .center
            )
            .onTapGesture {
                isMarqueeActive.toggle()
            }
            .accessibilityLabel(title)

            Text(artist)
                .font(artistFont)
                .foregroundStyle(.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}


extension Double {
    var mmss: String {
        guard isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(self))
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let hours = totalSeconds / 3600
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
