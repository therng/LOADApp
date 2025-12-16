import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Search State
    @Published var query: String = ""
    @Published var results: [Track] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Playback State
    @Published var nowPlaying: Track?
    @Published var isPlaying: Bool = false

    // Full player state (sync from AudioPlayerService)
    @Published var playerState: AudioPlayerService.PlayerState = .idle

    // MARK: - Queue
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0

    // MARK: - Search History (local UX)
    @Published var recentKeywords: [String] = []
    @Published var historyItems: [HistoryItem] = []
    @Published var isLoadingHistory: Bool = false
    @Published var historyError: String?

    // MARK: - Dependencies
    private let api: APIService
    private let player: AudioPlayerService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(api: APIService, player: AudioPlayerService) {
        self.api = api
        self.player = player

        // Sync player → view model
        player.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.isPlaying = state.isPlaying
                self.nowPlaying = state.track
                self.playerState = state
            }
            .store(in: &cancellables)
    }

    // Factory (used in LOADApp.swift)
    static func makeDefault() -> HomeViewModel {
        HomeViewModel(
            api: APIService.shared,
            player: AudioPlayerService.shared
        )
    }

    // MARK: - Search (MAIN)

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        results.removeAll()

        Task {
            defer { isLoading = false }

            do {
                let tracks = try await api.searchTracks(query: trimmed)
                results = tracks

                // Sync queue with results without auto-playing
                setQueue(tracks, startAt: 0, autoplay: false)

                // Maintain local search history (UX only)
                if !recentKeywords.contains(trimmed) {
                    recentKeywords.insert(trimmed, at: 0)
                    if recentKeywords.count > 10 {
                        recentKeywords.removeLast()
                    }
                }
            } catch {
                // Ignore cancellation silently
                if case APIService.APIError.cancelled = error {
                    return
                }

                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - History

    func loadHistory() {
        isLoadingHistory = true
        historyError = nil

        Task {
            defer { isLoadingHistory = false }

            do {
                let items = try await api.fetchHistory()
                historyItems = items.sorted { $0.timestamp > $1.timestamp }
            } catch {
                if case APIService.APIError.cancelled = error {
                    return
                }
                historyError = error.localizedDescription
            }
        }
    }

    func fetchHistoryDetail(for searchID: String) async throws -> SearchResponse {
        try await api.fetchSearchResult(id: searchID)
    }

    func applyHistoryResult(_ response: SearchResponse) {
        query = response.query
        results = response.results
        setQueue(response.results)
    }

    // MARK: - Playback Controls

    func play(_ track: Track) {
        if let index = queue.firstIndex(where: { $0.id == track.id }) {
            queueIndex = index
        }
        player.play(track: track)
    }

    func pause() {
        player.pause()
    }

    func togglePlayback() {
        isPlaying ? pause() : nowPlaying.map(play)
    }

    // MARK: - Queue Controls

    func setQueue(_ tracks: [Track], startAt index: Int = 0, autoplay: Bool = true) {
        queue = tracks
        queueIndex = max(0, min(index, tracks.count - 1))

        guard autoplay, !queue.isEmpty else { return }
        play(queue[queueIndex])
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
