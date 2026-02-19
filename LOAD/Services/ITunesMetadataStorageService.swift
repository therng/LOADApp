import Foundation
import Observation

struct ITunesTrackMetadata: Codable, Hashable {
    let artworkURL: URL?
    let releaseDate: String?
    let genre: String?
    let collectionName: String?
    let copyright: String?
    let duration: Int?
}

@MainActor
@Observable
final class ITunesMetadataStorageService {
    static let shared = ITunesMetadataStorageService()
    private let userDefaultsKey = "itunesTrackMetadata"

    private(set) var metadataByKey: [String: ITunesTrackMetadata] = [:]

    private init() {
        load()
    }

    func metadata(for track: Track) -> ITunesTrackMetadata? {
        metadataByKey[cacheKey(for: track)]
    }

    func fetchMetadata(for track: Track) async -> ITunesTrackMetadata? {
        let key = cacheKey(for: track)
        if let cached = metadataByKey[key] {
            return cached
        }

        let updatedTrack = await APIService.shared.fetchArtwork(for: track)
        let metadata = ITunesTrackMetadata(
            artworkURL: updatedTrack.artworkURL,
            releaseDate: updatedTrack.releaseDate,
            genre: updatedTrack.genre,
            collectionName: updatedTrack.collectionName,
            copyright: updatedTrack.copyright,
            duration: updatedTrack.duration
        )

        metadataByKey[key] = metadata
        save()
        return metadata
    }

    private func cacheKey(for track: Track) -> String {
        if !track.key.isEmpty {
            return "track.\(track.key)"
        }

        let artist = track.artist.lowercased()
        let title = track.title.lowercased()
        return "track.\(artist)-\(title)"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: ITunesTrackMetadata].self, from: data) else {
            metadataByKey = [:]
            return
        }

        metadataByKey = decoded
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(metadataByKey) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
