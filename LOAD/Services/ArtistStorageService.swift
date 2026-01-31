import Foundation
import Combine
import SwiftUI

// A singleton service to manage the user's collection of followed artists.
class ArtistStorageService: ObservableObject {
    static let shared = ArtistStorageService()
    private let userDefaultsKey = "followedArtists"

    @Published private(set) var artists: [Artist] = []

    private init() {
        loadArtists()
    }

    // MARK: - Public API

    func isArtistFollowed(artistName: String) -> Bool {
        artists.contains { $0.artistName.lowercased() == artistName.lowercased() }
    }

    @MainActor
    func toggleFollow(artistName: String) async {
        if isArtistFollowed(artistName: artistName) {
            // Unfollow
            artists.removeAll { $0.artistName.lowercased() == artistName.lowercased() }
            saveArtists()
        } else {
            // Follow
            do {
                if let artistResult = try await APIService.shared.searchForArtist(artistName) {
                    var newArtist = Artist(
                        artistId: artistResult.artistId ?? artistName.hashValue,
                        artistName: artistResult.artistName,
                        artistLinkUrl: artistResult.artistLinkUrl,
                        primaryGenreName: artistResult.primaryGenreName,
                        wrapperType: "artist"
                    )
                    
                    let artistId = newArtist.artistId
                    if let artistPageURL = URL(string: "https://music.apple.com/us/artist/\(artistId)") {
                        if let imageURL = await APIService.shared.fetchArtistArtworkURL(from: artistPageURL) {
                            newArtist.artworkURL = imageURL
                        }
                    }
                    
                    if !isArtistFollowed(artistName: newArtist.artistName) {
                        artists.append(newArtist)
                        saveArtists()
                    }
                }
            } catch {
                print("Error following artist: \(error.localizedDescription)")
            }
        }
    }
    
    func togglePin(for artist: Artist) {
        guard let index = artists.firstIndex(where: { $0.id == artist.id }) else { return }
        artists[index].isPinned.toggle()
        saveArtists()
    }
    
    func moveArtist(from source: IndexSet, to destination: Int) {
        artists.move(fromOffsets: source, toOffset: destination)
        saveArtists()
    }
    
    func unfollow(artist: Artist) {
        artists.removeAll { $0.id == artist.id }
        saveArtists()
    }


    // MARK: - Persistence

    private func loadArtists() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decodedArtists = try? JSONDecoder().decode([Artist].self, from: data) else {
            self.artists = []
            return
        }
        self.artists = decodedArtists
    }

    private func saveArtists() {
        if let encodedData = try? JSONEncoder().encode(artists) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
}
