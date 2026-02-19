import Foundation

struct Artist: Identifiable, Codable, Hashable {
    let artistId: Int
    var artistName: String
    var artistLinkURL: URL
    var primaryGenreName: String?
    var primaryGenreId: Int?
    var isPinned: Bool
    var artistImage: URL?

    var id: Int { artistId }

    init(
        artistId: Int,
        artistName: String,
        artistLinkURL: URL,
        primaryGenreName: String?,
        primaryGenreId: Int?,
        isPinned: Bool = false,
        artistImage: URL? = nil
    ) {
        self.artistId = artistId
        self.artistName = artistName
        self.artistLinkURL = artistLinkURL
        self.primaryGenreName = primaryGenreName
        self.primaryGenreId = primaryGenreId
        self.isPinned = isPinned
        self.artistImage = artistImage
    }

    init?(result: iTunesSearchResult) {
        guard let artistId = result.artistId,
              let artistLinkURL = result.artistLinkURL else {
            return nil
        }
        self.init(
            artistId: artistId,
            artistName: result.artistName,
            artistLinkURL: artistLinkURL,
            primaryGenreName: result.primaryGenreName,
            primaryGenreId: result.primaryGenreId,
            isPinned: false,
            artistImage: nil
        )
    }
}
