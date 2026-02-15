import Foundation
import Observation

@MainActor
@Observable
final class ArtistCollectionViewModel {
    private let storageService = ArtistStorageService.shared

    // MARK: - Properties

    var artists: [Artist] {
        storageService.artists
    }

    var pinnedArtists: [Artist] {
        artists.filter { $0.isPinned }
            .sorted { $0.artistName < $1.artistName }
    }

    var unpinnedArtists: [Artist] {
        artists.filter { !$0.isPinned }
            .sorted { $0.artistName < $1.artistName }
    }
    
    // MARK: - Actions

    func togglePin(for artist: Artist) {
        storageService.togglePin(for: artist)
    }

    func moveArtist(from source: IndexSet, to destination: Int) {
        storageService.moveArtist(from: source, to: destination)
    }

    func unfollow(artist: Artist) {
        storageService.unfollow(artist: artist)
    }

    func addArtist(name: String) async {
        guard !storageService.isArtistFollowed(artistName: name) else { return }
        await storageService.toggleFollow(artistName: name)
    }
}

