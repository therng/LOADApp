import Foundation

struct Track: Identifiable, Codable, Hashable {
    let artist: String
    let title: String
    let duration: Int
    let key: String

    
    // Field for storing local file path (added here only)
    var localURL: URL?
    var artworkURL: URL?
    var releaseDate: String?
    var customStreamURL: URL?

    // MARK: - Helpers
    private static let downloadBaseURL = URL(string: "https://nplay.idmp3s.xyz")!
    private static let streamBaseURL = URL(string: "https://nplay.idmp3s.xyz/stream")!

    var id: String { key }

    var download: URL {
        Self.downloadBaseURL.appendingPathComponent(key)
    }

    var stream: URL {
        customStreamURL ?? Self.streamBaseURL.appendingPathComponent(key)
    }

    // Centralized URL selection logic for playback
    var playURL: URL {
        if let local = localURL {
            return local
        }
        return stream
    }
    
    var durationText: String {
        let totalSeconds = max(0, duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Search Response
struct SearchResponse: Codable {
    let search_id: String
    var results: [Track]
    let query: String
    let count: Int
}

// MARK: - History Item
struct HistoryItem: Codable {
    let timestamp: Date
    let search_id: String
    let query: String
}

// MARK: - Local File Model
struct LocalFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: String
    let creationDate: String
}
struct iTunesSearchResponse: Codable {
    let results: [iTunesSearchResult]
}
struct iTunesSearchResult: Codable, Identifiable {
    // Fields for both albums and tracks
    let wrapperType: String
    let artistName: String
    let collectionId: Int
    let collectionName: String
    let artworkUrl100: URL?
    let releaseDate: Date
    let primaryGenreName: String
    let copyright: String?
    
    // Fields specific to tracks
    let trackId: Int?
    let trackName: String?
    let trackNumber: Int?
    let trackTimeMillis: Int?
    let previewUrl: URL?

    // Optional field for compilations
    let collectionArtistName: String?
    
    var id: Int { trackId ?? collectionId }
    
    var highResArtworkURL: URL? {
        guard let artworkURL = artworkUrl100 else { return nil }
        let highResURLString = artworkURL.absoluteString.replacingOccurrences(of: "100x100", with: "500x500")
        return URL(string: highResURLString)
    }
    
    var trackDuration: String? {
        guard let millis = trackTimeMillis else { return nil }
        let totalSeconds = millis / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
