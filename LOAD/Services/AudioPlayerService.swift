import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    @Published var shuffleMode: Bool = false
    @Published var repeatMode: Bool = false
    @Published var isPlaying = false
    @Published var currentTrack: Track?

    var elapsed: Double {
        guard let player else { return 0 }
        let time = CMTimeGetSeconds(player.currentTime())
        return time.isFinite && time >= 0 ? time : 0
    }

    var duration: Double? {
        guard let item = player?.currentItem else { return nil }
        let total = CMTimeGetSeconds(item.duration)
        return total.isFinite && total > 0 ? total : nil
    }

    private init() {
        configureAudioSession()
        configureRemoteCommands()
    }

    deinit {
        cleanup()
    }

    nonisolated private func cleanup() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let token = self.timeObserverToken, let player = self.player {
                player.removeTimeObserver(token)
            }
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - Playback Controls

    func play(track: Track) {
        if currentTrack == track && isPlaying {
            return
        }

        currentTrack = track
        configureAudioSession()

        let item = AVPlayerItem(url: track.stream)
        if let oldToken = timeObserverToken {
            player?.removeTimeObserver(oldToken)
            timeObserverToken = nil
        }
        player?.pause()
        player = AVPlayer(playerItem: item)

        addPeriodicTimeObserver()
        player?.play()
        isPlaying = true

        updateNowPlayingInfo(rate: 1.0, elapsed: 0)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingRate(0.0)
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingRate(1.0)
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        updateNowPlayingRate(0.0)
        currentTrack = nil
    }

    func seek(to seconds: Double, autoPlay: Bool = true) {
        guard let player else { return }

        let duration = player.currentItem.flatMap { item -> Double? in
            let total = CMTimeGetSeconds(item.duration)
            return total.isFinite && total > 0 ? total : nil
        }

        let clamped = min(max(0, seconds), duration ?? seconds)
        let target = CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.updateNowPlayingElapsed(clamped) }
            if autoPlay {
                Task { @MainActor in
                    self.player?.play()
                    self.isPlaying = true
                    self.updateNowPlayingRate(1.0)
                }
            }
        }
    }

    func skip(by delta: Double, autoPlay: Bool = true) {
        guard let player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        seek(to: current + delta, autoPlay: autoPlay)
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    // MARK: - Remote Commands

    private func configureRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.addTarget { [weak self] _ in
            self?.resume(); return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.isPlaying ? self.pause() : self.resume(); return .success
        }

        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: 15); return .success
        }
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -15); return .success
        }

        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: e.positionTime, autoPlay: isPlaying); return .success
        }
    }

    // MARK: - Now Playing Info

    private func addPeriodicTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let elapsed = CMTimeGetSeconds(time)
            Task { @MainActor in self.updateNowPlayingElapsed(elapsed) }
        }
    }

    private func updateNowPlayingInfo(rate: Float, elapsed: Double) {
        guard let track = currentTrack else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate
        ]

        if let duration = Self.parseDuration(track.duration) {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingRate(_ rate: Float) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed(_ elapsed: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func parseDuration(_ text: String) -> Double? {
        let parts = text.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        if parts.count == 2 { return parts[0] * 60 + parts[1] }
        if parts.count == 3 { return parts[0] * 3600 + parts[1] * 60 + parts[2] }
        return nil
    }
}
