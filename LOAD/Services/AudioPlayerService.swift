import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit
import MediaPlayer

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Singleton
    static let shared = AudioPlayerService()

    // MARK: - Public State (UI-facing)

    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentTrack: Track?
    @Published private(set) var artworkImage: UIImage?

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isLoading: Bool = false

    @Published var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    @Published var isSeeking: Bool = false
    @Published private(set) var didFinishPlayback: Bool = false

    @Published var volume: Float = 1.0 {
        didSet {
            let clamped = min(max(volume, 0), 1)
            if volume != clamped {
                volume = clamped
                return
            }
            avPlayer?.volume = volume
            audioPlayer?.volume = volume
        }
    }

    // MARK: - Backends

    private var avPlayer: AVPlayer?
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Observers / Timers

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var progressTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        configureAudioSession()
        setupRemoteTransportControls()
    }

    // MARK: - Queue API

    var upcomingTracks: [Track] {
        guard currentIndex + 1 < queue.count else { return [] }
        return Array(queue[currentIndex + 1 ..< queue.count])
    }

    func setQueue(_ tracks: [Track], startAt index: Int = 0) {
        stop()
        queue = tracks
        currentIndex = min(max(index, 0), max(tracks.count - 1, 0))

        guard !queue.isEmpty else { return }
        playTrack(at: currentIndex)
    }

    func playFromQueue(index: Int) {
        guard index >= 0, index < queue.count else { return }
        playTrack(at: index)
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
    }

    func enqueueNext(_ track: Track) {
        queue.insert(track, at: currentIndex + 1)
    }

    func removeUpcoming(at offsets: IndexSet) {
        let absoluteOffsets = IndexSet(offsets.map { $0 + currentIndex + 1 })
        queue.remove(atOffsets: absoluteOffsets)
    }

    func moveUpcoming(from source: IndexSet, to destination: Int) {
        let absoluteSource = IndexSet(source.map { $0 + currentIndex + 1 })
        let absoluteDestination = destination + currentIndex + 1
        queue.move(fromOffsets: absoluteSource, toOffset: absoluteDestination)
    }

    func clearUpcoming() {
        guard currentIndex + 1 < queue.count else { return }
        queue.removeSubrange(currentIndex + 1 ..< queue.count)
    }

    func shuffleUpcoming() {
        guard currentIndex + 1 < queue.count else { return }
        let upcoming = queue.suffix(from: currentIndex + 1).shuffled()
        queue.removeSubrange(currentIndex + 1 ..< queue.count)
        queue.append(contentsOf: upcoming)
    }

    func playNext() {
        advance()
    }

    func playPrevious() {
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            playTrack(at: currentIndex - 1)
        } else {
            seek(to: 0)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Playback Control

    func play() {
        guard !isPlaying else { return }
        if currentTrack == nil, !queue.isEmpty {
            playTrack(at: currentIndex)
        } else {
            resumeBackend()
        }
    }

    func pause() {
        pauseBackend()
        isPlaying = false
        updateNowPlayingInfo() // Update state for lock screen
    }

    func stop() {
        stopBackend()
        isPlaying = false
        isLoading = false
        currentTrack = nil
        currentTime = 0
        duration = 0
        didFinishPlayback = false
        artworkImage = nil
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Seeking

    func startScrubbing() {
        isSeeking = true
    }

    func endScrubbing(at time: Double) {
        isSeeking = false
        seek(to: time)
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), duration)

        if let player = audioPlayer {
            player.currentTime = target
            if !isSeeking { currentTime = target }
        } else if let player = avPlayer {
            let time = CMTime(seconds: target, preferredTimescale: 1_000_000_000)
            player.seek(to: time)
            if !isSeeking { currentTime = target }
        }
        updateNowPlayingInfo() // Sync seeking changes
    }

    // MARK: - Core Playback Flow

    private func playTrack(at index: Int) {
        guard index >= 0, index < queue.count else { return }

        // Fully reset previous playback state
        stopBackend()
        
        didFinishPlayback = false
        currentIndex = index
        currentTrack = queue[index]
        currentTime = 0
        duration = 0
        isLoading = true
        artworkImage = nil
        
        // Initial info update (clears previous track info)
        updateNowPlayingInfo()

        let track = queue[index]

        if let localURL = track.localURL {
            playLocal(url: localURL)
        } else {
            playStream(url: track.stream)
        }
        
        updateArtwork(for: track)
    }

    private func updateArtwork(for track: Track) {
        let trackID = track.id // Capture ID to prevent race conditions
        Task {
            let (updatedTrack, image) = await APIService.shared.fetchArtworkImage(for: track)
            
            // Ensure the track we fetched artwork for is still the current one
            guard self.currentTrack?.id == trackID else { return }
            
            // Update track metadata (artwork URL, release date, etc.)
            self.currentTrack = updatedTrack
            
            if let image = image?.makeThreadSafe() {
                self.artworkImage = image
                self.updateNowPlayingInfo()
            }
        }
    }

    private func handleFinishedPlayback() {
        guard !didFinishPlayback else { return }

        didFinishPlayback = true
        isPlaying = false
        currentTime = 0

        advance()
    }

    private func advance() {
        guard currentIndex + 1 < queue.count else {
            stop()
            return
        }
        playTrack(at: currentIndex + 1)
    }

    // MARK: - Local Backend (AVAudioPlayer)

    private func playLocal(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            duration = player.duration
            isPlaying = true
            isLoading = false
            
            updateNowPlayingInfo()
            startProgressTimer()
        } catch {
            print("❌ AVAudioPlayer init failed: \(error.localizedDescription)")
            isLoading = false
            isPlaying = false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.handleFinishedPlayback()
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer, !self.isSeeking else { return }
                self.currentTime = player.currentTime
                // Optionally update MPNowPlayingInfoCenter periodically if drift occurs,
                // but usually setting it on play/pause/seek is sufficient.
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Stream Backend (AVPlayer)

    private func playStream(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = volume
        player.allowsExternalPlayback = true
        avPlayer = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleFinishedPlayback()
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 1_000_000_000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self, !self.isSeeking else { return }
                let seconds = CMTimeGetSeconds(time)
                guard seconds.isFinite else { return }
                self.currentTime = seconds

                if let dur = player.currentItem?.duration.seconds, dur.isFinite, dur > 0 {
                    self.duration = dur
                    // Update duration once known for streams
                     if abs(self.duration - dur) > 0.1 {
                        self.updateNowPlayingInfo()
                     }
                }
            }
        }

        player.play()
        isPlaying = true
        isLoading = false
        updateNowPlayingInfo()
    }

    // MARK: - Backend Control

    private func pauseBackend() {
        audioPlayer?.pause()
        avPlayer?.pause()
    }

    private func resumeBackend() {
        audioPlayer?.play()
        avPlayer?.play()
        isPlaying = true
        updateNowPlayingInfo() // Sync playback state
    }

    private func stopBackend() {
        // Stop audio backends
        audioPlayer?.stop()
        audioPlayer = nil
        
        avPlayer?.pause()
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        avPlayer = nil
        
        // Stop observers/timers
        stopProgressTimer()
        
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        
        // Reset playback states
        isLoading = false
        // Note: We don't reset `isPlaying` here because `stopBackend` is called 
        // during track transitions where we might technically still want to be "playing" logically.
        // Explicit stops should set isPlaying = false.
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
    }
    
    // MARK: - Remote Transport Controls (Lock Screen)
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNext() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPrevious() }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        
        if let image = artworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = createArtwork(from: image)
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    nonisolated private func createArtwork(from image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
