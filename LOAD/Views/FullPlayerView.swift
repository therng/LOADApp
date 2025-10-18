import SwiftUI
import Combine
import UIKit
import SafariServices

@available(iOS 18.0, *)
struct FullPlayerView: View {
    let track: Track
    @EnvironmentObject private var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    // observe player singleton to get elapsed/duration/isPlaying
    @ObservedObject private var player = AudioPlayerService.shared

    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    @State private var showDownloadSafari = false

    var body: some View {
        // ลบ NavigationTitle/Toolbar ออก เปลี่ยนเป็น header ภายในเอง
        VStack(spacing: 16) {
            // Drag handle
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .accessibilityHidden(true)

            // Header: Track info + Download button ด้านขวา
            HStack(alignment: .top, spacing: 12) {
                // Artwork placeholder
                RoundedRectangle(cornerRadius: 10)
                    .fill(materialBackground())
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Download button (แทน Safari icon)
                Button {
                    // เปิดลิงก์ดาวน์โหลด (ใช้ vm.openInSafari ที่ชี้ไป URL download)
                    vm.openInSafari(track)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download")
            }
            .padding(.horizontal)

            // Artwork large area
            RoundedRectangle(cornerRadius: 12)
                .fill(materialBackground())
                .frame(width: 260, height: 260)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.9))
                )

            // Progress / slider
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

                Slider(value: Binding(get: {
                    isSeeking ? sliderValue : player.elapsed
                }, set: { newVal in
                    sliderValue = newVal
                }), in: 0 ... (player.duration ?? max(1, player.elapsed)), onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing {
                        player.seek(to: sliderValue, autoPlay: player.isPlaying)
                    }
                })
            }
            .padding(.horizontal)

            // Playback controls
            HStack(spacing: 30) {
                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                Button {
                    if player.isPlaying {
                        vm.pause()
                    } else {
                        if vm.nowPlaying?.id == track.id {
                            vm.resume()
                        } else {
                            vm.play(track)
                        }
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                }

                Button {
                    player.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .background(
            // Glass effect background สำหรับ sheet/inspector
            glassBackground()
                .ignoresSafeArea()
        )
        .presentationDragIndicator(.visible)
        .onAppear {
            // ensure player is playing this track when opened
            if vm.nowPlaying?.id != track.id {
                vm.play(track)
            }
            sliderValue = player.elapsed
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard !isSeeking else { return }
            sliderValue = player.elapsed
        }
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func timeString(from seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let min = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", min, sec)
    }

    @ViewBuilder
    private func glassBackground() -> some View {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .background(
                    .thinMaterial
                )
                .overlay(
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 0))
                )
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }

    // Explicit type-erased ShapeStyle to avoid inference issues
    private func materialBackground() -> AnyShapeStyle {
        if #available(iOS 26.0, *) {
            return AnyShapeStyle(.regularMaterial)
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
