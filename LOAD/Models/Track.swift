import Foundation


struct BeatportTrack: Codable, Identifiable {
    let trackId: Int
    let trackUrl: URL?

    var id: Int { trackId }

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case trackUrl = "track_url"
    }
}

// MARK: - Track (Main model for search & playback)
struct Track: Identifiable, Codable, Hashable {
    var artist: String
    var title: String
    var duration: Int
    let key: String
    
    
    var id: String { key }
    // Local & remote assets
    var localURL: URL?
    var artworkURL: URL?
    var releaseDate: String?
    var customStreamURL: URL?
    var copyright: String?
    var genre: String?
    var collectionName: String?

    enum CodingKeys: String, CodingKey {
        case artist
        case title
        case duration
        case key
        case localURL
        case artworkURL
        case releaseDate
        case customStreamURL
        case copyright
        case genre
        case collectionName
    }

    init(
        artist: String,
        title: String,
        duration: Int,
        key: String,
        localURL: URL? = nil,
        artworkURL: URL? = nil,
        releaseDate: String? = nil,
        customStreamURL: URL? = nil,
        copyright: String? = nil,
        genre: String? = nil,
        collectionName: String? = nil
    ) {
        self.artist = artist
        self.title = title
        self.duration = duration
        self.key = key
        self.localURL = localURL
        self.artworkURL = artworkURL
        self.releaseDate = releaseDate
        self.customStreamURL = customStreamURL
        self.copyright = copyright
        self.genre = genre
        self.collectionName = collectionName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        localURL = try container.decodeIfPresent(URL.self, forKey: .localURL)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        customStreamURL = try container.decodeIfPresent(URL.self, forKey: .customStreamURL)
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
    }

    // Computed URLs
    private static let downloadBase = URL(string: "https://nplay.idmp3s.xyz")!
    private static let streamBase = URL(string: "https://nplay.idmp3s.xyz/stream")!

    var download: URL {
        Self.downloadBase.appendingPathComponent(key)
    }

    var stream: URL {
        customStreamURL ?? Self.streamBase.appendingPathComponent(key)
    }

    var playURL: URL {
        localURL ?? stream
    }

    // Duration formatter (localized & clean)
    var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(duration)) ?? "0:00"
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - API Responses
struct SearchResponse: Codable {
    let searchId: String
    var results: [Track]
    let query: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case searchId = "search_id"
        case results
        case query
        case count
    }
}

struct HistoryItem: Codable, Identifiable {
    var id: String { searchId }
    let timestamp: Date
    let searchId: String
    let query: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case searchId = "search_id"
        case query
    }
}

// MARK: - iTunes Search
struct iTunesSearchResponse: Codable {
    let results: [iTunesSearchResult]
}

struct iTunesSearchResult: Codable, Identifiable, Equatable {
    let wrapperType: String
    let artistType: String?
    let artistName: String
    let collectionId: Int?
    let collectionName: String?
    let collectionViewURL: URL?
    let artworkURL100: URL?
    let releaseDate: Date?
    let copyright: String?
  
    // Track-specific
    let artistId: Int?
    let artistLinkURL: URL?
    let trackCount: Int?
    let trackId: Int?
    let trackName: String?
    let trackNumber: Int?
    let trackTimeMillis: Int?
    let previewURL: URL?

    // Compilation
    let collectionArtistName: String?
    
    // Additional artist info
    let amgArtistId: Int?
    let primaryGenreName: String?
    let primaryGenreId: Int?
    
    enum CodingKeys: String, CodingKey {
        case wrapperType
        case artistType
        case artistName
        case collectionId
        case collectionName
        case collectionViewURL = "collectionViewUrl"
        case artworkURL100 = "artworkUrl100"
        case releaseDate
        case copyright
        case artistId
        case artistLinkURL = "artistLinkUrl"
        case trackCount
        case trackId
        case trackName
        case trackNumber
        case trackTimeMillis
        case previewURL = "previewUrl"
        case collectionArtistName
        case amgArtistId
        case primaryGenreName
        case primaryGenreId
    }

    var id: Int {
        if wrapperType == "track", let trackId {
            return trackId
        }
        if wrapperType == "artist", let artistId {
            return artistId
        }
        return collectionId ?? 0
    }

    var artworkURL: URL? {
        guard let artworkURL100 = artworkURL100 else { return nil }
        let str = artworkURL100.absoluteString.replacingOccurrences(of: "100x100", with: "1000x1000")
        return URL(string: str)
    }
    
    var trackDuration: String? {
        guard let millis = trackTimeMillis else { return nil }
        let total = millis / 1000
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    static func == (lhs: iTunesSearchResult, rhs: iTunesSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}
