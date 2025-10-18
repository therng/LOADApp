import Combine
import UIKit
import SwiftUI
import AVFoundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchText: String = "" {
        didSet {
            query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    @Published var results: [Track] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // ✅ เพิ่ม state สำหรับ mini player
    @Published var nowPlaying: Track? = nil
    @Published var isPlaying: Bool = false

    private let player = AudioPlayerService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 🎧 Sync nowPlaying กับ player
        player.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.nowPlaying = track
            }
            .store(in: &cancellables)

        // 🔁 Sync isPlaying state
        player.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.isPlaying = playing
            }
            .store(in: &cancellables)
    }

    // MARK: - Search
    func search() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { [weak self] in
            do {
                let tracks = try await APIService.shared.searchTracks(query: trimmed)
                await MainActor.run {
                    self?.results = tracks
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Playback
    func play(_ track: Track) {
        player.play(track: track)
    }

    func pause() {
        player.pause()
    }

    func resume() {
        player.resume()
    }

    func stop() {
        player.stop()
    }

    // MARK: - Open in Safari
    func openInSafari(_ track: Track) {
        UIApplication.shared.open(track.download, options: [:], completionHandler: nil)
    }
}
