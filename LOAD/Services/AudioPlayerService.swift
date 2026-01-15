import AVFoundation
import Combine
import Foundation
import MediaPlayer
@preconcurrency import ActivityKit
import SwiftUI

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    // MARK: - Published State
    
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var userQueue: [Track] = []
    @Published private(set) var continueQueue: [Track] = []
    @Published private(set) var repeatOne = false
    @Published private(set) var repeatAll = false
    @Published private(set) var shuffle = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    /// Compatibility helper for existing views.
    var continuePlaying: [Track] { continueQueue }
    
    let progress = PlaybackProgress()
    
    // MARK: - Internals
    
    private var history: [String] = []
    private var historySearchIDs: [String] = []
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var liveActivityStorage: Any?
    private var isTopUpInProgress = false
    
    @available(iOS 17.0, *)
    private var nowPlayingActivity: Activity<NowPlayingAttributes>? {
        get { liveActivityStorage as? Activity<NowPlayingAttributes> }
        set { liveActivityStorage = newValue }
    }
    
    private enum AdvanceReason {
        case autoplay
        case manual
    }
    
    // MARK: - Types
    
    final class PlaybackProgress: ObservableObject {
        @Published var currentTime: Double = 0
        @Published var duration: Double = 0
    }
    
    @available(iOS 17.0, *)
    struct NowPlayingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var title: String
            var artist: String
            var isPlaying: Bool
            var elapsed: Double
            var duration: Double
        }
        
        var trackID: String
        var title: String
        var artist: String
    }
    
    // MARK: - Init
    
    private init() {
        configureAudioSession()
    }
    
    // MARK: - Public Toggles
    
    func toggleRepeatOne() {
        repeatOne.toggle()
        if repeatOne { repeatAll = false }
    }
    
    func toggleRepeatAll() {
        repeatAll.toggle()
        if repeatAll { repeatOne = false }
    }
    
    func toggleShuffle() {
        shuffle.toggle()
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }
    
    // MARK: - Queue Management
    
    func setQueue(_ tracks: [Track], startAt: Track? = nil) {
        if startAt == nil {
            userQueue = tracks
            continueQueue.removeAll()
        }
        if let startAt {
            playNow(track: startAt)
        }
    }
    
    func enqueueNext(_ track: Track) {
        stopContinueMode()
        userQueue.removeAll { $0.id == track.id }
        userQueue.insert(track, at: 0)
    }
    
    func addToQueue(_ track: Track) {
        stopContinueMode()
        userQueue.removeAll { $0.id == track.id }
        userQueue.append(track)
    }
    
    func addToQueue(key: String) {
        Task {
            if let track = try? await APIService.shared.fetchTrack(key: key) {
                addToQueue(track)
            }
        }
    }
    
    func removeFromUserQueue(at offsets: IndexSet) {
        userQueue.remove(atOffsets: offsets)
    }
    
    func moveUserQueue(from source: IndexSet, to destination: Int) {
        userQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    func clearUserQueue() {
        userQueue.removeAll()
    }
    
    func shuffleUserQueue() {
        guard userQueue.count > 1 else { return }
        userQueue.shuffle()
    }
    
    func addHistory(from response: SearchResponse) {
        pushHistorySearchID(response.search_id)
        response.results.forEach { pushHistory(key: $0.key) }
    }
    
    // MARK: - Playback Controls
    
    func play(track: Track) {
        playNow(track: track)
    }
    
    func playNow(track: Track) {
        isLoading = true
        errorMessage = nil
        stopContinueMode()
        startPlayback(with: track)
        // ✨ Populate continueQueue immediately after starting playback
        topUpContinueQueue()
    }
    
    func playNow(key: String) {
        Task { await resolveAndPlay(key: key) }
    }
    
    func playTrack(key: String) {
        playNow(key: key)
    }
    
    func playNext() {
        Task { await advance(reason: .manual) }
    }
    
    func playPrevious() {
        if progress.currentTime > 3 {
            seek(to: 0)
            return
        }
        
        // Find the most recent historical track that is not the current one.
        if let currentID = currentTrack?.id {
            if let previousKey = history.first(where: { $0 != currentID }) {
                Task { await resolveAndPlay(key: previousKey) }
                return
            }
        }
        seek(to: 0)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingRate(0.0)
        if #available(iOS 17.0, *) {
            Task { @MainActor in
                await updateLiveActivity(isPlaying: false)
            }
        }
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingRate(1.0)
        if #available(iOS 17.0, *) {
            Task { @MainActor in
                await updateLiveActivity(isPlaying: true)
            }
        }
    }
    
    func stop() {
        updateNowPlayingRate(0.0)
        if #available(iOS 17.0, *) {
            Task { @MainActor in
                await updateLiveActivity(isPlaying: false)
            }
        }
        Task { @MainActor in
            if #available(iOS 17.0, *) {
                await endLiveActivity()
            }
        }
        cleanupPlayer()
        currentTrack = nil
        isPlaying = false
        isLoading = false
        clearNowPlaying()
    }
    
    func seek(to seconds: Double) {
        guard let player = player else { return }
        let clamped = max(0, seconds)
        let target = CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: target) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progress.currentTime = clamped
                self.updateNowPlayingElapsed(clamped)
                if #available(iOS 17.0, *) {
                    await self.updateLiveActivity(isPlaying: self.isPlaying)
                }
            }
        }
    }
    
    // MARK: - Internal Playback Lifecycle
    
    private func startPlayback(with track: Track) {
        cleanupPlayer()
        currentTrack = track
        pushHistory(key: track.id)
        
        let item = AVPlayerItem(url: track.stream)
        let player = AVPlayer(playerItem: item)
        self.player = player
        
        observeEnd(for: item)
        observeTime(on: player)
        
        progress.duration = Double(track.duration)
        progress.currentTime = 0
        
        player.play()
        isPlaying = true
        isLoading = false
        configureNowPlaying(for: track)
        updateNowPlayingRate(1.0)
        if #available(iOS 17.0, *) {
            startLiveActivity(for: track)
        }
    }
    
    private func observeEnd(for item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.handlePlaybackFinished()
            }
        }
    }
    
    private func observeTime(on player: AVPlayer) {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite {
                    self.progress.currentTime = seconds
                    self.updateNowPlayingElapsed(seconds)
                    if #available(iOS 17.0, *) {
                        await self.updateLiveActivity(isPlaying: self.isPlaying)
                    }
                }
                
                if let item = player.currentItem {
                    let durationSeconds = CMTimeGetSeconds(item.duration)
                    if durationSeconds.isFinite && durationSeconds > 0 {
                        self.progress.duration = durationSeconds
                    }
                }
            }
        }
    }
    
    private func handlePlaybackFinished() async {
        await advance(reason: .autoplay)
    }
    
    private func advance(reason: AdvanceReason) async {
        if repeatOne, reason == .autoplay, currentTrack != nil {
            if let player {
                await player.seek(to: .zero)
                player.play()
            }
            isPlaying = true
            progress.currentTime = 0
            updateNowPlayingElapsed(0)
            if #available(iOS 17.0, *) {
                await updateLiveActivity(isPlaying: true)
            }
            return
        }
        
        if let nextUser = popUserQueue() {
            stopContinueMode()
            playNow(track: nextUser)
            return
        }
        
        // Continue mode - simplified to use popContinueQueue() directly
        if let nextContinue = popContinueQueue() {
            playNow(track: nextContinue)
            return
        }
        
        if repeatAll {
            continueQueue.removeAll()
            if let loopTrack = popContinueQueue() {
                playNow(track: loopTrack)
                return
            }
        }
        
        stop()
    }
    
    private func popUserQueue() -> Track? {
        guard !userQueue.isEmpty else { return nil }
        if shuffle {
            let index = Int.random(in: 0..<userQueue.count)
            return userQueue.remove(at: index)
        }
        return userQueue.removeFirst()
    }
    
    private func popContinueQueue() -> Track? {
        guard !continueQueue.isEmpty else { return nil }
        if shuffle {
            let index = Int.random(in: 0..<continueQueue.count)
            return continueQueue.remove(at: index)
        }
        return continueQueue.removeFirst()
    }
    
    private func ensureContinueQueue(target: Int) async {
        let cappedTarget = min(target, 5)
        let needed = cappedTarget - continueQueue.count
        if needed <= 0 { return }
        await topUpContinueQueue(target: cappedTarget)
    }
    
    private func topUpContinueQueue(target: Int) async {
        guard userQueue.isEmpty else { return }
        guard continueQueue.count < 5 else { return }

        var queue = continueQueue
        var existingKeys = Set(queue.map(\.id))
        if let currentID = currentTrack?.id {
            existingKeys.insert(currentID)
        }
        userQueue.forEach { existingKeys.insert($0.id) }
    // MARK: - Continue Queue - New Implementation
    
    /// Populate the continue queue with new API flow:
    /// 1️⃣ GET /history → get all search IDs
    /// 2️⃣ Random select one search_id
    /// 3️⃣ GET /history/{search_id} → get results: [Track]
    /// 4️⃣ Random select one Track from results
    private func topUpContinueQueue() {
        guard !isTopUpInProgress else { return }
        guard userQueue.isEmpty else { return }  // Only topup when userQueue is empty
        guard continueQueue.count < 5 else { return }  // Don't exceed 5 tracks
        
        isTopUpInProgress = true
        
        Task {
            do {
                let response = try await APIService.shared.fetchSearchResult(id: searchID)
                guard let historyKey = response.results.randomElement()?.key else { continue }
                let track = try await APIService.shared.fetchTrack(key: historyKey)
                if existingKeys.contains(track.id) { continue }
                queue.append(track)
                existingKeys.insert(track.id)
                // Step 1️⃣: GET /history to get all search IDs
                let histories = try await APIService.shared.fetchHistory()
                
                // Step 2️⃣: Select a random search_id
                guard let randomHistory = histories.randomElement() else {
                    isTopUpInProgress = false
                    return
                }
                
                let searchId = randomHistory.id ?? randomHistory.search_id
                
                // Step 3️⃣: GET /history/{search_id} to get tracks for this search
                let response = try await APIService.shared.fetchSearchResult(id: searchId)
                
                // Step 4️⃣: Select a random track from results and add to queue
                if let randomTrack = response.results.randomElement() {
                    // Check for duplicates
                    var existingKeys = Set(continueQueue.map(\.id))
                    if let currentID = currentTrack?.id {
                        existingKeys.insert(currentID)
                    }
                    userQueue.forEach { existingKeys.insert($0.id) }
                    
                    if !existingKeys.contains(randomTrack.id) {
                        continueQueue.append(randomTrack)
                    }
                }
                
                isTopUpInProgress = false
                
                // Recursively call to fill up to 5 tracks
                if continueQueue.count < 5 {
                    topUpContinueQueue()
                }
                
            } catch {
#if DEBUG
                print("❌ TopUp continueQueue failed:", error.localizedDescription)
#endif
                isTopUpInProgress = false
            }
        }
    }
    
    private func stopContinueMode() {
        continueQueue.removeAll()
    }
    
    // MARK: - Networking Helpers
    
    private func resolveAndPlay(key: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let track = try await APIService.shared.fetchTrack(key: key)
            playNow(track: track)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func pushHistory(key: String) {
        history.removeAll { $0 == key }
        history.insert(key, at: 0)
        if history.count > 100 {
            history.removeLast(history.count - 100)
        }
    }

    private func pushHistorySearchID(_ id: String) {
        historySearchIDs.removeAll { $0 == id }
        historySearchIDs.insert(id, at: 0)
        if historySearchIDs.count > 100 {
            historySearchIDs.removeLast(historySearchIDs.count - 100)
        }
    }
    
    // MARK: - Audio Session / Cleanup
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
#if DEBUG
            print("Audio session setup failed: \(error.localizedDescription)")
#endif
        }
    }
    
    private func cleanupPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        timeObserver = nil
        endObserver = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        progress.currentTime = 0
        progress.duration = 0
    }
    
    // MARK: - Now Playing / Live Activity

    @available(iOS 17.0, *)
    private func startLiveActivity(for track: Track) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = NowPlayingAttributes(
            trackID: track.id,
            title: track.title,
            artist: track.artist
        )
        let content = ActivityContent(
            state: NowPlayingAttributes.ContentState(
                title: track.title,
                artist: track.artist,
                isPlaying: isPlaying,
                elapsed: progress.currentTime,
                duration: Double(track.duration)
            ),
            staleDate: nil
        )
        do {
            nowPlayingActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity start failed:", error.localizedDescription)
            #endif
        }
    }

    @available(iOS 17.0, *)
    private func updateLiveActivity(isPlaying: Bool) async {
        guard let activity = nowPlayingActivity,
              let track = currentTrack else { return }
        let activityContent = ActivityContent(
            state: NowPlayingAttributes.ContentState(
                title: track.title,
                artist: track.artist,
                isPlaying: isPlaying,
                elapsed: progress.currentTime,
                duration: Double(track.duration)
            ),
            staleDate: nil
        )
        await activity.update(activityContent)
    }

    @available(iOS 17.0, *)
    private func endLiveActivity() async {
        guard let activity = nowPlayingActivity else { return }
        let track = currentTrack
        let activityContent = ActivityContent(
            state: NowPlayingAttributes.ContentState(
                title: track?.title ?? "",
                artist: track?.artist ?? "",
                isPlaying: false,
                elapsed: progress.currentTime,
                duration: Double(track?.duration ?? 0)
            ),
            staleDate: nil
        )
        await activity.end(activityContent, dismissalPolicy: .immediate)
        nowPlayingActivity = nil
    }
    private func configureNowPlaying(for track: Track) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyPlaybackDuration] = Double(track.duration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingElapsed(_ time: Double) {
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
}
