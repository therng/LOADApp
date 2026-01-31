import Foundation

// Based on iTunes Search API (entity=musicArtist) with app-specific extensions.
struct Artist: Identifiable, Codable, Hashable {
    // iTunes Fields
    let artistId: Int
    let artistName: String
    let artistLinkUrl: URL?
    let primaryGenreName: String?
    let wrapperType: String

    // App-specific Extension Fields
    var artworkURL: URL?
    var isPinned: Bool = false
    var sortOrder: Int = 0
    var followedAt: Date = Date()

    var id: Int { artistId }

    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.artistId == rhs.artistId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(artistId)
    }
}
