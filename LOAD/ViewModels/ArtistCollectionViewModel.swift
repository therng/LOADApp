import Foundation
import SwiftUI
import Combine

@MainActor
class ArtistCollectionViewModel: ObservableObject {
    @Published private(set) var artists: [Artist] = []
    private var cancellables = Set<AnyCancellable>()
    private let storageService = ArtistStorageService.shared

    // Computed properties to easily separate pinned and other artists
    var pinnedArtists: [Artist] {
        artists.filter { $0.isPinned }.sorted { $0.artistName < $1.artistName }
    }

    var unpinnedArtists: [Artist] {
        artists.filter { !$0.isPinned }.sorted { $0.artistName < $1.artistName }
    }

    init() {
        // Subscribe to updates from the central storage service
        storageService.$artists
            .receive(on: DispatchQueue.main)
            .assign(to: \.artists, on: self)
            .store(in: &cancellables)
    }

    func togglePin(for artist: Artist) {
        storageService.togglePin(for: artist)
    }

    func moveArtist(from source: IndexSet, to destination: Int) {
        storageService.moveArtist(from: source, to: destination)
    }

    func unfollow(artist: Artist) {
        storageService.unfollow(artist: artist)
    }
}

