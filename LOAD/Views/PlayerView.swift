import SwiftUI
import Combine
import UIKit
import SafariServices

// MARK: – Views
struct MusicPlayerSheetView: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: HomeViewModel
    @Binding var showSheet: Bool
    @Namespace var animationNamespace

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // For large detent full‑screen glass background
            if showSheet {
                Color.clear
                    .background(.regularMaterial)
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                    let image = phase.image {
                        Image(systemName: "music.note").resizable()
                        ProgressView()
                    
                .frame(width: 200, height: 200)
                .cornerRadius(16)
                .shadow(radius: 10)
                .matchedGeometryEffect(id: "albumArt", in: animationNamespace)
                Text(vm.trackTitle)
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                    .matchedGeometryEffect(id: "title", in: animationNamespace)

                Text(vm.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "artist", in: animationNamespace)

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
                HStack(spacing: 30) {
                    Button(action: vm.toggleShuffle) {
                        Image(systemName: vm.shuffleMode ? "shuffle.circle.fill" : "shuffle.circle")
                            .font(.title2)
                    }
                    Button(action: vm.nextTrack) {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                    Button(action: vm.previousTrack) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }
                    Button(action: vm.toggleRepeat) {
                        Image(systemName: vm.repeatMode ? "repeat.circle.fill" : "repeat.circle")
                            .font(.title2)
                    }
                }
                .padding(.top, 10)

                HStack(spacing: 30) {
                    AirPlayButton()
                    Button(action: vm.downloadAction) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                    }
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .background(.thinMaterial) // translucent background for sheet content
            .cornerRadius(20)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .onAppear {
            // maybe start album art rotation when playing
        }
    }

    func timeString(_ seconds: Double) -> String {
        let intSec = Int(seconds)
        let m = intSec / 60
        let s = intSec % 60
        return String(format: "%d:%02d", m, s)
    }
}



struct PlayerView: View {
    let track: Track
    @EnvironmentObject private var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    // observe player singleton to get elapsed/duration/isPlaying
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var vm: HomeViewModel
    
    @Binding var showSheet: Bool
    @Namespace var animationNamespace
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    @State private var showDownloadSafari = false
    @State private var showLiked: Bool = false
    @State private var showUnliked: Bool = false
    @State private var showMore: Bool = false
    
    
    var body: some View {
            VStack(alignment: .leading) {
                Text(vm.searcrch).font(.headline)
                    .matchedGeometryEffect(id: "title", in: animationNamespace)
                Text(vm.artistName).font(.subheadline).foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "artist", in: animationNamespace)
            }
            Spacer()
            Button(action: {
                vm.playPause()
            }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
            }
        }
        .padding()
        .background(.ultraThinMaterial) // liquid glass effect
        .onTapGesture {
            withAnimation(.spring()) {
                showSheet = true
            }
        }
    }
}

struct MusicPlayerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: HomeViewModel
    @Binding var showSheet: Bool
    @Namespace var animationNamespace

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // For large detent full‑screen glass background
            if showSheet {
                Color.clear
                    .background(.regularMaterial)
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                AsyncImage(url: vm.albumURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                    } else if phase.error != nil {
                        Image(systemName: "music.note").resizable()
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 200, height: 200)
                .cornerRadius(16)
                .shadow(radius: 10)
                .matchedGeometryEffect(id: "albumArt", in: animationNamespace)
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
                Text(vm.trackTitle)
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                    .matchedGeometryEffect(id: "title", in: animationNamespace)

                Text(vm.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "artist", in: animationNamespace)

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
                HStack(spacing: 30) {
                    Button(action: vm.toggleShuffle) {
                        Image(systemName: vm.shuffleMode ? "shuffle.circle.fill" : "shuffle.circle")
                            .font(.title2)
                    }
                    Button(action: vm.nextTrack) {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                    Button(action: vm.previousTrack) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }
                    Button(action: vm.toggleRepeat) {
                        Image(systemName: vm.repeatMode ? "repeat.circle.fill" : "repeat.circle")
                            .font(.title2)
                    }
                }
                .padding(.top, 10)

                HStack(spacing: 30) {
                    AirPlayButton()
                    Button(action: vm.downloadAction) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                    }
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .background(.thinMaterial) // translucent background for sheet content
            .cornerRadius(20)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .onAppear {
            // maybe start album art rotation when playing
        }
    }

    func timeString(_ seconds: Double) -> String {
        let intSec = Int(seconds)
        let m = intSec / 60
        let s = intSec % 60
        return String(format: "%d:%02d", m, s)
    }
}



struct PlayerView: View {
    let track: Track
    @EnvironmentObject private var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    // observe player singleton to get elapsed/duration/isPlaying
    @ObservedObject private var player = AudioPlayerService.shared

    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    @State private var showDownloadSafari = false

   
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
