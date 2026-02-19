import Foundation
import SwiftUI

// A singleton service to manage the user's collection of followed artists.
@MainActor
@Observable
class ArtistStorageService {
    static let shared = ArtistStorageService()
    private let userDefaultsKey = "followedArtists"

    private(set) var artists: [Artist] = []

    private init() {
        loadArtists()
    }

    // MARK: - Public API

    func isArtistFollowed(artistName: String) -> Bool {
        artists.contains { $0.artistName.lowercased() == artistName.lowercased() }
    }

    func toggleFollow(artistName: String) async {
        if isArtistFollowed(artistName: artistName) {
            unfollow(artistName: artistName)
        } else {
            await follow(artistName: artistName)
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

    // MARK: - Internal Logic

    private func unfollow(artistName: String) {
        artists.removeAll { $0.artistName.lowercased() == artistName.lowercased() }
        saveArtists()
    }

        private func follow(artistName: String) async {
            do {
                guard let result = try await APIService.shared.searchForArtist(artistName, limit: 1) else { return }
                guard var newArtist = Artist(result: result) else { return }
    
                // Fetch artist image from the artist link on the search result
                if let imageURL = await APIService.shared.fetchArtistImage(from: newArtist.artistLinkURL) {
                    newArtist.artistImage = imageURL
                }
                
                if !isArtistFollowed(artistName: newArtist.artistName) {
                    artists.append(newArtist)
                    saveArtists()
                }
            } catch {
                print("Error following artist: \(error.localizedDescription)")
            }
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

