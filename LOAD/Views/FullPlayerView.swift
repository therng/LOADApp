import SwiftUI
import UIKit

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var pendingCoverOpen = false
    @State private var isTitleMarqueeActive = false
    
    var body: some View {
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
                    .purple.opacity(0.8), .blue.opacity(0.8), .cyan.opacity(0.8),
                    .pink.opacity(0.8), .indigo.opacity(0.8), .blue.opacity(0.8),
                    .red.opacity(0.8), .purple.opacity(0.8), .pink.opacity(0.8)
                ]
            )
            .ignoresSafeArea()
            GeometryReader { proxy in
                let artworkSize = min(proxy.size.width * 0.78, 320)

                VStack(spacing: 20) {
                    ZStack {
                        Text("Now Playing")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))

                        HStack {
                            Spacer()

                            Menu {
                                if let track = player.currentTrack {
                                    TrackActionMenuItems(track: track) { url in
                                        safariURL = url
                                    }
                                } else {
                                    Button("No Track", systemImage: "music.note") {}
                                        .disabled(true)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 8)

                    // Large artwork
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.1))

                        if let coverURL = player.currentCoverURL {
                            AsyncImage(url: coverURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Image(systemName: "music.note")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.white.opacity(0.6))
                                default:
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .onTapGesture {
                        if let coverURL = player.currentCoverURL {
                            safariURL = coverURL
                        } else if let track = player.currentTrack {
                            pendingCoverOpen = true
                            player.requestCoverIfNeeded(for: track)
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Album artwork")

                    // Track info
                    if let track = player.currentTrack {
                        VStack(spacing: 8) {
                            MarqueeText(
                                text: track.title,
                                font: titleUIFont,
                                color: .white,
                                isActive: isTitleMarqueeActive,
                                speed: 32,
                                spacing: 32
                            )
                            .onTapGesture {
                                isTitleMarqueeActive.toggle()
                            }
                            .accessibilityLabel(track.title)

                            Text(track.artist)
                                .font(.init(artistUIFont))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Progress slider
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { player.currentTime },
                                set: { player.seek(to: $0) }
                            ),
                            in: 0...max(player.duration, 1)
                        )
                        .tint(.white)

                        HStack {
                            Text(player.currentTime.mmss)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .monospacedDigit()

                            Spacer()

                            Text(player.duration.mmss)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Controls
                    HStack(spacing: 40) {
                        Button {
                            player.playPrevious()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }

                        Button {
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                            // iOS 18: Scale effect
                                .symbolEffect(.bounce, value: player.isPlaying)
                        }

                        Button {
                            player.playNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                    }

                    AirPlayRoutePicker()
                        .frame(width: 45, height: 45)
                        .accessibilityLabel("AirPlay")

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )
        ) {
            if let safariURL {
                SafariView(url: safariURL)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
            }
        }
        .task(id: player.currentTrack?.id) {
            if let track = player.currentTrack {
                player.requestCoverIfNeeded(for: track)
            }
        }
        .onChange(of: player.currentTrack?.id) { _, _ in
            pendingCoverOpen = false
            isTitleMarqueeActive = false
        }
        .onChange(of: player.currentCoverURL) { _, newValue in
            guard pendingCoverOpen, let newValue else { return }
            pendingCoverOpen = false
            safariURL = newValue
        }
    }

    private var titleUIFont: UIFont {
        let baseSize = UIFont.preferredFont(forTextStyle: .title2).pointSize
        return UIFontMetrics(forTextStyle: .title2)
            .scaledFont(for: UIFont.systemFont(ofSize: baseSize, weight: .bold))
    }

    private var artistUIFont: UIFont {
        let baseSize = UIFont.preferredFont(forTextStyle: .title3).pointSize
        return UIFontMetrics(forTextStyle: .title3)
            .scaledFont(for: UIFont.systemFont(ofSize: baseSize, weight: .regular))
    }
}

extension Double {
    var mmss: String {
        guard self.isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(self.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct MarqueeText: View {
    let text: String
    let font: UIFont
    let color: Color
    let isActive: Bool
    let speed: CGFloat
    let spacing: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width

            ZStack(alignment: .leading) {
                if isActive && textWidth > containerWidth {
                    HStack(spacing: spacing) {
                        measuredText
                        measuredText
                    }
                    .offset(x: offset)
                    .onAppear {
                        startAnimation(containerWidth: containerWidth)
                    }
                    .onChange(of: textWidth) { _, _ in
                        startAnimation(containerWidth: containerWidth)
                    }
                    .onChange(of: containerWidth) { _, _ in
                        startAnimation(containerWidth: containerWidth)
                    }
                    .onChange(of: isActive) { _, _ in
                        startAnimation(containerWidth: containerWidth)
                    }
                } else {
                    measuredText
                }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
        }
        .frame(height: font.lineHeight)
    }

    private var measuredText: some View {
        Text(text)
            .font(.init(font))
            .foregroundStyle(color)
            .lineLimit(1)
            .background(WidthReader())
            .onPreferenceChange(WidthKey.self) { value in
                if textWidth != value {
                    textWidth = value
                }
            }
    }

    private func startAnimation(containerWidth: CGFloat) {
        guard isActive, textWidth > containerWidth else {
            offset = 0
            return
        }

        let distance = textWidth + spacing
        let duration = Double(distance / speed)
        offset = 0

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}

private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
        }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
