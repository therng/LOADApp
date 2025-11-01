import SwiftUI
import Combine

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: HomeViewModel
    @ObservedObject private var player = AudioPlayerService.shared

    let track: Track
    let namespace: Namespace.ID

    @State private var sliderValue: Double = 0
    @State private var isSeeking = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            glassBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                artwork
                trackDetails
                progressSlider
                playbackControls
                secondaryControls

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: configureOnAppear)
        .onReceive(timer) { _ in
            updateSliderFromPlayer()
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(materialBackground())
            .frame(width: 260, height: 260)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.9))
            )
            .matchedGeometryEffect(id: "albumArt", in: namespace)
            .shadow(radius: 12)
    }

    private var trackDetails: some View {
        VStack(spacing: 4) {
            Text(track.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .matchedGeometryEffect(id: "title", in: namespace)

            Text(track.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .matchedGeometryEffect(id: "artist", in: namespace)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text(timeString(from: isSeeking ? sliderValue : player.elapsed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timeString(from: player.duration ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: {
                        isSeeking ? sliderValue : player.elapsed
                    },
                    set: { newValue in
                        sliderValue = newValue
                    }
                ),
                in: 0...(player.duration ?? max(1, player.elapsed + 1)),
                onEditingChanged: sliderEditingChanged
            )
        }
        .padding(.horizontal)
    }

    private var playbackControls: some View {
        HStack(spacing: 30) {
            Button {
                player.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Button {
                if player.isPlaying {
                    vm.pause()
                } else if player.currentTrack == track {
                    vm.resume()
                } else {
                    vm.play(track)
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .buttonStyle(.plain)

            Button {
                player.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var secondaryControls: some View {
        HStack(spacing: 24) {
            AirPlayRoutePickerView()
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .accessibilityLabel("AirPlay")

            Button {
                vm.openInSafari(track)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download")

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss player")
        }
        .padding(.horizontal)
    }

    private func sliderEditingChanged(_ editing: Bool) {
        isSeeking = editing
        if !editing {
            player.seek(to: sliderValue, autoPlay: player.isPlaying)
        }
    }

    private func configureOnAppear() {
        sliderValue = player.elapsed
        if player.currentTrack != track {
            vm.play(track)
        }
    }

    private func updateSliderFromPlayer() {
        guard !isSeeking else { return }
        sliderValue = player.elapsed
    }

    private func timeString(from seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    @ViewBuilder
    private func glassBackground() -> some View {
        if #available(iOS 16.4, *) {
            Rectangle()
                .fill(.ultraThinMaterial)
        } else {
            Rectangle()
                .fill(Color.black.opacity(0.85))
        }
    }

    private func materialBackground() -> AnyShapeStyle {
        if #available(iOS 16.4, *) {
            return AnyShapeStyle(.regularMaterial)
        } else {
            return AnyShapeStyle(Color.black.opacity(0.4))
        }
    }
}
