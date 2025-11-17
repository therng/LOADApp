import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    // Search state
    @Published var query: String = ""
    @Published var results: [Track] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Playback state
    @Published var nowPlaying: Track?
    @Published var isPlaying: Bool = false
    
    // Enhanced player state (full state machine)
    @Published var playerState: AudioPlayerService.PlayerState = .idle

    // Queue system
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0

    // Search history
    @Published var recentKeywords: [String] = []
    
    private let api: APIService
    private let player: AudioPlayerService
    private var cancellables = Set<AnyCancellable>()
    
    // Designated initializer requires explicit dependencies (avoids accessing @MainActor singletons from a nonisolated context)
    init(api: APIService, player: AudioPlayerService) {
        self.api = api
        self.player = player

        player.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isPlaying = state.isPlaying
                self?.nowPlaying = state.track
                self?.playerState = state
            }
            .store(in: &cancellables)
    }
    
    // Convenience factory to create a default instance using the shared singletons on the main actor
    static func makeDefault() -> HomeViewModel {
        HomeViewModel(api: APIService.shared, player: AudioPlayerService.shared)
    }
    
    // MARK: - Search
    
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // Use the concrete APIService’s method signature
                let tracks = try await api.searchTracks(query: trimmed)
                results = tracks
                
                // Maintain search history
                if !trimmed.isEmpty, !recentKeywords.contains(trimmed) {
                    recentKeywords.insert(trimmed, at: 0)
                    if recentKeywords.count > 10 {
                        recentKeywords.removeLast()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    // MARK: - Playback
    
    func play(_ track: Track) {
        player.play(track: track)
    }
    
    func pause() {
        player.pause()
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else if let track = nowPlaying {
            play(track)
        }
    }
    
    // MARK: - Queue Controls

    func setQueue(_ tracks: [Track], startAt index: Int = 0) {
        queue = tracks
        queueIndex = max(0, min(index, tracks.count - 1))
        if !queue.isEmpty {
            play(queue[queueIndex])
        }
    }

    func playNext() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex + 1) % queue.count
        play(queue[queueIndex])
    }

    func playPrevious() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        play(queue[queueIndex])
    }
}
