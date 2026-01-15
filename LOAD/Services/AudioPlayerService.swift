import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit
import CoreImage

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Singleton
    static let shared = AudioPlayerService()

    // MARK: - Public State (UI-facing)

    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentTrack: Track?
    @Published private(set) var artworkImage: UIImage?
    @Published private(set) var dominantColor: Color?

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
    private var dominantColorTask: Task<Void, Never>?

    // MARK: - Init

    override init() {
        super.init()
        configureAudioSession()
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
    }

    func stop() {
        stopBackend()
        isPlaying = false
        isLoading = false
        currentTrack = nil
        currentTime = 0
        duration = 0
        didFinishPlayback = false
        dominantColorTask?.cancel()
        dominantColorTask = nil
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
    }

    // MARK: - Core Playback Flow

    private func playTrack(at index: Int) {
        guard index >= 0, index < queue.count else { return }

        stopBackend()
        didFinishPlayback = false
        currentIndex = index
        currentTrack = queue[index]
        currentTime = 0
        duration = 0
        isLoading = true
        artworkImage = nil
        dominantColor = nil

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
            let updatedTrack = await APIService.shared.fetchArtwork(for: track)
            
            // Ensure the track we fetched artwork for is still the current one
            guard self.currentTrack?.id == trackID else { return }
            self.currentTrack = updatedTrack
            
            if let artworkData = await APIService.shared.fetchArtworkData(for: updatedTrack) {
                let image = UIImage(data: artworkData)?.makeThreadSafe()
                
                // Final check before updating UI
                guard self.currentTrack?.id == trackID else { return }

                self.artworkImage = image
                
                self.dominantColorTask?.cancel()
                guard let image else { return }

                self.dominantColorTask = Task.detached(priority: .utility) {
                    guard let avg = image.averageColor() else { return }
                    let toned = avg.tonedForBackground()

                    await MainActor.run {
                        // Check one last time before setting color
                        guard self.currentTrack?.id == trackID else { return }
                        withAnimation(.easeInOut(duration: 0.8)) {
                            self.dominantColor = toned
                        }
                    }
                }
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

            startProgressTimer()
        } catch {
            isLoading = false
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
                }
            }
        }

        player.play()
        isPlaying = true
        isLoading = false
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
    }

    private func stopBackend() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopProgressTimer()

        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }

        avPlayer?.pause()
        avPlayer = nil
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

private extension UIImage {
    func makeThreadSafe() -> UIImage? {
        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
private extension Color {
    /// Returns a version of the color toned to work better as a background.
    /// Bright colors are darkened slightly; dark colors are lightened slightly.
    nonisolated func tonedForBackground() -> Color {
        // Convert to RGBA via UIColor
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Perceived luminance (sRGB)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

        // Blend factor determines how much to move toward target (black/white)
        let blend: CGFloat = 0.18

        let tonedRed: CGFloat
        let tonedGreen: CGFloat
        let tonedBlue: CGFloat

        if luminance > 0.7 {
            // Too bright: blend slightly toward black
            tonedRed   = r * (1 - blend)
            tonedGreen = g * (1 - blend)
            tonedBlue  = b * (1 - blend)
        } else if luminance < 0.3 {
            // Too dark: blend slightly toward white
            tonedRed   = r + (1 - r) * blend
            tonedGreen = g + (1 - g) * blend
            tonedBlue  = b + (1 - b) * blend
        } else {
            // Mid-range: small desaturation for subtlety
            let gray = (r + g + b) / 3
            let desat: CGFloat = 0.12
            tonedRed   = r + (gray - r) * desat
            tonedGreen = g + (gray - g) * desat
            tonedBlue  = b + (gray - b) * desat
        }

        let tonedColor = UIColor(red: tonedRed, green: tonedGreen, blue: tonedBlue, alpha: a)
        return Color(tonedColor)
    }
}
