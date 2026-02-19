import Foundation

struct SpotifyPlaylist: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let owner: SpotifyUser
    let images: [SpotifyImage]?
    let tracks: SpotifyPlaylistTrackInfo
    let externalUrls: [String: URL]? // Renamed from external_urls
    
    var title: String { name }
    var creator: String { owner.displayName ?? owner.id }
    var trackCount: Int { tracks.total }
    var coverArtURL: URL? {
        images?.first?.url
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, owner, images, tracks
        case externalUrls = "externalUrls" // Already matching standard codable with camelCase
    }
    
    // Conforming to Hashable
    static func == (lhs: SpotifyPlaylist, rhs: SpotifyPlaylist) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SpotifyPlaylist {
    static let mocks: [SpotifyPlaylist] = [
        SpotifyPlaylist(
            id: "1",
            name: "Summer Vibes",
            owner: SpotifyUser(displayName: "Spotify", id: "spotify"),
            images: [SpotifyImage(url: URL(string: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce870f7d54982a")!, width: 640, height: 640)],
            tracks: SpotifyPlaylistTrackInfo(href: URL(string: "https://api.spotify.com/v1/playlists/37i9dQZF1DX843Qf4dFj9u/tracks")!, total: 50),
            externalUrls: nil
        ),
        SpotifyPlaylist(
            id: "2",
            name: "Chill Lo-Fi",
            owner: SpotifyUser(displayName: "User", id: "user1"),
            images: [SpotifyImage(url: URL(string: "https://i.scdn.co/image/ab67616d00001e021a6e7e1f4b8f0a3d4f8f0a3d")!, width: 640, height: 640)],
            tracks: SpotifyPlaylistTrackInfo(href: URL(string: "https://api.spotify.com/v1/playlists/37i9dQZF1EpyH4QdK6XoP2/tracks")!, total: 100),
            externalUrls: nil
        )
    ]
}

struct SpotifyUser: Codable, Hashable {
    let displayName: String? // Renamed from display_name
    let id: String
}

struct SpotifyPlaylistTrackInfo: Codable, Hashable {
    let href: URL
    let total: Int
}

struct SpotifyTrack: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artists: [SpotifyArtistSimplified]
    let album: SpotifyAlbumSimplified
    let durationMs: Int // Renamed from duration_ms
    let uri: String
    let externalUrls: [String: URL]? // Renamed from external_urls
    
    var title: String { name }
    var artist: String { artists.first?.name ?? "Unknown Artist" }
    var duration: TimeInterval { TimeInterval(durationMs / 1000) }
    var coverArtURL: URL? { album.images?.first?.url }
    
    // Conforming to Hashable
    static func == (lhs: SpotifyTrack, rhs: SpotifyTrack) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SpotifyArtistSimplified: Codable, Hashable {
    let id: String
    let name: String
}

struct SpotifyAlbumSimplified: Codable, Hashable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
}

struct SpotifyDevice: Identifiable, Codable, Hashable {
    let id: String
    let isActive: Bool // Renamed from is_active
    let isPrivateSession: Bool // Renamed from is_private_session
    let isRestricted: Bool // Renamed from is_restricted
    let name: String
    let type: String
    let volumePercent: Int? // Renamed from volume_percent
}

// API Response Structs
struct SpotifyPlaylistsResponse: Codable {
    let items: [SpotifyPlaylist]
    let next: URL?
}

struct SpotifyPlaylistItemsResponse: Codable {
    let items: [SpotifyPlaylistItem]
    let next: URL?
}

struct SpotifyPlaylistItem: Codable {
    let track: SpotifyTrack?
}

// Moved from SpotifyAPIService.swift to SpotifyModels.swift for better organization
struct SpotifyImage: Codable, Hashable {
    let url: URL
    let width: Int?
    let height: Int?
}
