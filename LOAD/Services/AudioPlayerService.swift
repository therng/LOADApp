import AVFoundation
import Combine
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    // MARK: - Player State Machine

    enum PlayerState: Equatable {
        case idle
        case loading(Track)
        case ready(Track)
        case playing(Track)
        case paused(Track)
        case failed(message: String)

        var track: Track? {
            switch self {
            case .idle:
                return nil
            case .loading(let t),
                 .ready(let t),
                 .playing(let t),
                 .paused(let t):
                return t
            case .failed:
                return nil
            }
        }

        var isPlaying: Bool {
            if case .playing = self { return true }
            return false
        }
    }

    // MARK: - Published State

    @Published private(set) var state: PlayerState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    var currentTrack: Track? { state.track }
    var isPlaying: Bool { state.isPlaying }

    let playbackFinished = PassthroughSubject<Void, Never>()

    // MARK: - Private

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Init

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        observeInterruptions()
    }

    deinit {
        // deinit runs from a nonisolated context; hop to the main actor
        Task { @MainActor [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.cleanupPlayer()
            NotificationCenter.default.removeObserver(strongSelf)
        }
    }

    // MARK: - Public Controls

    func play(track: Track) {
        // ถ้าเล่นเพลงเดิมอยู่แล้ว
        if case let .playing(current) = state, current.id == track.id {
            return
        }

        // ถ้าหยุดพักเพลงเดิม → resume
        if case let .paused(current) = state, current.id == track.id {
            resume()
            return
        }

        state = .loading(track)
        startNewPlayer(with: track)
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard let track = state.track else { return }
        player?.play()
        state = .playing(track)
        updateNowPlayingRate(1.0)
    }

    func pause() {
        guard let track = state.track else { return }
        player?.pause()
        state = .paused(track)
        updateNowPlayingRate(0.0)
    }

    func stop() {
        cleanupPlayer()
        state = .idle
        clearNowPlaying()
    }

    func seek(to seconds: Double) {
        guard let player = player else { return }

        let total = duration
        let clamped = max(0, min(seconds, total > 0 ? total : seconds))
        let target = CMTime(
            seconds: clamped,
            preferredTimescale: CMTimeScale(NSEC_PER_SEC)
        )

        player.seek(to: target) { [weak self] _ in
            let clampedCopy = clamped
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = clampedCopy
                self.updateNowPlayingElapsedTime(clampedCopy)
            }
        }
    }

    // MARK: - Private Helpers

    private func startNewPlayer(with track: Track) {
        NotificationCenter.default.removeObserver(self)
        cleanupPlayer()

        let item = AVPlayerItem(url: track.stream)
        let player = AVPlayer(playerItem: item)
        self.player = player

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        setupTimeObserver(for: player)

        player.play()
        state = .playing(track)

        duration = Double(track.duration)
        currentTime = 0

        configureNowPlaying(for: track)
        updateNowPlayingRate(1.0)
    }

    private func setupTimeObserver(for player: AVPlayer) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            let secondsCopy = CMTimeGetSeconds(time)
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                let seconds = secondsCopy
                if seconds.isFinite {
                    self.currentTime = seconds
                    self.updateNowPlayingElapsedTime(seconds)
                }
                if let item = player.currentItem {
                    let durationSeconds = CMTimeGetSeconds(item.duration)
                    if durationSeconds.isFinite && durationSeconds > 0 {
                        self.duration = durationSeconds
                    }
                }
            }
        }
    }

    private func cleanupPlayer() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }

        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentTime = 0
        duration = 0
    }

    // MARK: - Audio Session / Interruption

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothHFP]
            )
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            // Avoid capturing self directly in a potentially @Sendable closure
            let rawUserInfo = notification.userInfo
            let typeNumber = rawUserInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber
            let optionsNumber = rawUserInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber

            Task { @MainActor [weak self] in
                guard let self else { return }

                guard let typeNumber,
                      let type = AVAudioSession.InterruptionType(rawValue: typeNumber.uintValue) else {
                    return
                }

                switch type {
                case .began:
                    if self.isPlaying {
                        self.pause()
                    }
                case .ended:
                    let optionsRaw = optionsNumber?.uintValue ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                    if options.contains(.shouldResume),
                       case let .paused(track) = self.state {
                        self.play(track: track)
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Remote Command Center / Now Playing (Lock Screen + Dynamic Island)

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = e.positionTime
            Task { @MainActor in
                self?.seek(to: position)
            }
            return .success
        }
    }

    private func configureNowPlaying(for track: Track) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist

        // Duration is provided by Track as seconds (Int). Convert to Double for Now Playing.
        info[MPMediaItemPropertyPlaybackDuration] = Double(track.duration)

        // Default artwork using asset "LogoW" (fallback to SF Symbol if missing)
        if let artwork = makeDefaultArtwork() {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func makeDefaultArtwork() -> MPMediaItemArtwork? {
        // Use app asset named "LogoW" if available; otherwise fall back to an SF Symbol.
        if let baseImage = UIImage(named: "LogoW") {
            return MPMediaItemArtwork(boundsSize: baseImage.size) { requestedSize in
                // If no specific size requested, return the base image.
                guard requestedSize != .zero, requestedSize != baseImage.size else {
                    return baseImage
                }

                // Scale the asset to the requested size while preserving aspect ratio.
                let aspectWidth = requestedSize.width / baseImage.size.width
                let aspectHeight = requestedSize.height / baseImage.size.height
                let scale = min(aspectWidth, aspectHeight)
                let targetSize = CGSize(
                    width: baseImage.size.width * scale,
                    height: baseImage.size.height * scale
                )

                let renderer = UIGraphicsImageRenderer(size: requestedSize)
                return renderer.image { _ in
                    let x = (requestedSize.width - targetSize.width) / 2
                    let y = (requestedSize.height - targetSize.height) / 2
                    baseImage.draw(in: CGRect(x: x, y: y, width: targetSize.width, height: targetSize.height))
                }
            }
        }

        // Fallback: Use an SF Symbol if the asset is missing.
        let config = UIImage.SymbolConfiguration(pointSize: 160, weight: .regular)
        guard let image = UIImage(systemName: "waveform.circle.fill", withConfiguration: config) ??
                          UIImage(systemName: "music.note", withConfiguration: config) else {
            return nil
        }

        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func updateNowPlayingElapsedTime(_ time: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingRate(_ rate: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Notifications

    @objc private func playerItemDidPlayToEnd(_ notification: Notification) {
        guard let track = state.track else {
            state = .idle
            updateNowPlayingRate(0.0)
            playbackFinished.send()
            return
        }

        state = .ready(track)
        updateNowPlayingRate(0.0)
        playbackFinished.send()
    }
}
