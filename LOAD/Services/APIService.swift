import Foundation

@MainActor
final class APIService {

    static let shared = APIService()

    // MARK: - Base URL
    private let endpointBase = "https://postauditory-unmanoeuvred-lizette.ngrok-free.dev"

    // MARK: - Errors
    enum APIError: LocalizedError {
        case invalidURL
        case badResponse(statusCode: Int)
        case decodingError
        case network(Error)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidURL:               return "Invalid request URL."
            case .badResponse(let status):  return "Server error (\(status))."
            case .decodingError:            return "Unable to read server data."
            case .network(let err):         return err.localizedDescription
            case .cancelled:               return "Request cancelled."
            }
        }
    }

    // MARK: - Response Models
    struct DeleteResponse: Decodable {
        let deletedCount: Int
        
        enum CodingKeys: String, CodingKey {
            case deletedCount = "deleted_count"
        }
    }
    
    struct DeleteItemResponse: Decodable {
        let deleted: Bool
        let searchId: String
        
        enum CodingKeys: String, CodingKey {
            case deleted
            case searchId = "search_id"
        }
    }

    // MARK: - Formatters
    static let yearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f
    }()

    private static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let iso8601WithFractional = ISO8601DateFormatter()
            iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            iso8601WithFractional.timeZone = TimeZone(secondsFromGMT: 0)

            let iso8601NoFractional = ISO8601DateFormatter()
            iso8601NoFractional.formatOptions = [.withInternetDateTime]
            iso8601NoFractional.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = iso8601WithFractional.date(from: string) { return date }
            if let date = iso8601NoFractional.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }()

    // MARK: - Init
    private init() {}

    // MARK: - Session
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 25
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private var currentSearchTask: Task<SearchResponse, Error>?

    // MARK: - Caches
    private let artworkCache        = NSCache<NSURL, NSData>()
    private let iTunesResponseCache = NSCache<NSURL, NSData>()
}

// MARK: - Endpoint
private extension APIService {

    enum Endpoint {
        case health
        case search(query: String)
        case track(key: String)
        case history
        case historyItem(id: String)
        case deleteAll
        case deleteItem(id: String)
        case beatportID(artist: String, title: String, mix: String?)

        func url(base: String) throws -> URL {
            guard var components = URLComponents(string: base) else {
                throw APIError.invalidURL
            }

            switch self {
            case .health:
                components.path = "/health"

            case .search(let query):
                components.path = "/search"
                components.queryItems = [URLQueryItem(name: "track", value: query)]

            case .track(let key):
                components.path = "/track/\(key)"

            case .history:
                components.path = "/history"

            case .historyItem(let id):
                components.path = "/history/\(id)"

            case .deleteAll:
                components.path = "/delete"

            case .deleteItem(let id):
                components.path = "/delete/\(id)"

            case .beatportID(let artist, let title, let mix): // ✅ fixed parameter order
                components.path = "/beatport"
                var items: [URLQueryItem] = [
                    URLQueryItem(name: "artist", value: artist),
                    URLQueryItem(name: "title",  value: title)
                ]
                if let mix = mix, !mix.trimmingCharacters(in: .whitespaces).isEmpty {
                    items.append(URLQueryItem(name: "mix", value: mix))
                }
                components.queryItems = items
            }

            guard let url = components.url else { throw APIError.invalidURL }
            return url
        }
    }
}

// MARK: - Public API
extension APIService {

    func warmUp() async {
        guard let url = try? Endpoint.health.url(base: endpointBase) else { return }
        _ = try? await session.data(from: url)
    }

    func search(query: String) async throws -> (searchId: String, tracks: [Track]) {
        currentSearchTask?.cancel()

        let task = Task<SearchResponse, Error> {
            let url = try Endpoint.search(query: query).url(base: endpointBase)
            return try await request(url: url)
        }
        currentSearchTask = task

        do {
            let response = try await task.value
            return (response.searchId, response.results)
        } catch is CancellationError {
            throw APIError.cancelled
        }
    }

    func fetchTrack(key: String) async throws -> Track {
        let url = try Endpoint.track(key: key).url(base: endpointBase)
        return try await request(url: url)
    }

    func fetchHistory() async throws -> [HistoryItem] {
        let url = try Endpoint.history.url(base: endpointBase)
        return try await request(url: url)
    }

    func fetchHistoryItem(with id: String) async throws -> SearchResponse {
        let url = try Endpoint.historyItem(id: id).url(base: endpointBase)
        return try await request(url: url)
    }

    func deleteAllHistoryItems() async throws -> Int {
        let url = try Endpoint.deleteAll.url(base: endpointBase)
        let response: DeleteResponse = try await request(url: url, method: "DELETE")
        return response.deletedCount
    }

    func deleteHistoryItem(with id: String) async throws -> Bool {
        let url = try Endpoint.deleteItem(id: id).url(base: endpointBase)
        let response: DeleteItemResponse = try await request(url: url, method: "DELETE")
        return response.deleted
    }

    func beatportTrackID(title: String, artist: String) async throws -> (trackId: Int, trackUrl: URL?) {
        let parsedArtist = artist.parseArtists().joined(separator: ", ")
        let parsed       = title.parseTitleAndMix()

        #if DEBUG
        print("🔍 [Beatport Query] artist=\(parsedArtist), title=\(parsed.title), mix=\(parsed.mix ?? "nil")")
        #endif

        let url = try Endpoint.beatportID(artist: parsedArtist, title: parsed.title, mix: parsed.mix)
            .url(base: endpointBase)

        let response: BeatportTrack = try await request(url: url)

        #if DEBUG
        print("🔍 [Beatport ID]: \(response.trackId), URL: \(String(describing: response.trackUrl))")
        #endif

        return (response.trackId, response.trackUrl)
    }
}

// MARK: - Core Request
private extension APIService {

    func request<T: Decodable>(url: URL, method: String = "GET") async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        #if DEBUG
        print("🌐 [API] \(method): \(url.absoluteString)")
        #endif

        do {
            let (data, response) = try await session.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(statusCode: -1)
            }
            guard (200...299).contains(http.statusCode) else {
                #if DEBUG
                print("❌ HTTP \(http.statusCode):", String(data: data, encoding: .utf8) ?? "")
                #endif
                throw APIError.badResponse(statusCode: http.statusCode)
            }

            do {
                return try Self.apiDecoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                #if DEBUG
                print("❌ Decoding Error: \(decodingError)")
                #endif
                throw APIError.decodingError
            } catch {
                throw APIError.decodingError
            }

        } catch is CancellationError { throw APIError.cancelled
        } catch let api as APIError   { throw api
        } catch                       { throw APIError.network(error) }
    }
}

// MARK: - iTunes / Artwork
extension APIService {

    func findArtwork(parsedTitle: (title: String, mix: String?),
                     parsedArtists: [String]) async -> (
                        artworkURL: URL,
                        artistName: String,
                        collectionId: Int?,
                        collectionName: String?,
                        collectionViewURL: URL?,
                        artworkURL100: URL?,
                        releaseDate: Date?,
                        primaryGenreName: String?,
                        copyright: String?
                     )? {
        let term = parsedArtists.joined(separator: "+") + "+" + parsedTitle.title

        guard let url = try? iTunesSearchURL(term: term, entity: "album", extra: [
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "attribute", value: "albumTerm"),
            URLQueryItem(name: "sort", value: "popular"),
        ]) else { return nil }

        guard let response: iTunesSearchResponse = try? await fetchITunesData(url: url) else {
            return nil
        }

        guard let result = response.results
            .filter({ ($0.collectionName ?? "").localizedCaseInsensitiveContains(parsedTitle.title) })
            .sorted(by: { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) })
            .first else { return nil }

        guard let highResURL = URL(string: result.artworkURL100?.absoluteString.replacingOccurrences(of: "100x100", with: "1000x1000") ?? "") else { return nil }

        return (
                artworkURL: highResURL,
                artistName: result.artistName,
                collectionId: result.collectionId,
                collectionName: result.collectionName,
                collectionViewURL: result.collectionViewURL,
                artworkURL100: result.artworkURL100,
                releaseDate: result.releaseDate,
                primaryGenreName: result.primaryGenreName,
                copyright: result.copyright
 
        )
    }

    func fetchArtwork(for track: Track) async -> Track {
        var t = track

        let missingMetadata = t.artist.isEmpty || t.title.isEmpty
            || t.duration == 0
            || (t.genre ?? "").isEmpty
            || (t.collectionName ?? "").isEmpty

        let missingArtwork = t.artworkURL == nil
            || (t.releaseDate ?? "").isEmpty
            || (t.copyright ?? "").isEmpty

        guard missingMetadata || missingArtwork else { return t }

        // Derive parsed values once, reused by both branches
        let parsedTitle   = t.title.parseTitleAndMix()
        let parsedArtists = t.artist.parseArtists()

        if missingMetadata,
           let meta = await findTrackMetadata(parsedTitle: parsedTitle, parsedArtists: parsedArtists) {
            if t.artist.isEmpty                          { t.artist = meta.artistName }
            if t.title.isEmpty                           { t.title  = meta.trackName ?? t.title }
            if t.duration == 0, let ms = meta.trackTimeMillis { t.duration = max(0, ms / 1000) }
            if (t.genre ?? "").isEmpty                   { t.genre           = meta.primaryGenreName }
            if (t.collectionName ?? "").isEmpty          { t.collectionName  = meta.collectionName }
        }

        if missingArtwork,
           let art = await findArtwork(parsedTitle: parsedTitle, parsedArtists: parsedArtists) {
            t.artworkURL = art.artworkURL
            t.copyright  = art.copyright ?? ""
            if let date = art.releaseDate {
                t.releaseDate = APIService.yearFormatter.string(from: date)
            }
        }

        return t
    }

    func fetchArtworkData(for track: Track) async -> Data? {
        let resolvedTrack: Track
        if track.artworkURL == nil {
            resolvedTrack = await fetchArtwork(for: track)
            guard resolvedTrack.artworkURL != nil else { return nil }
        } else {
            resolvedTrack = track
        }

        guard let url = resolvedTrack.artworkURL else { return nil }

        if let cached = artworkCache.object(forKey: url as NSURL) {
            return cached as Data
        }

        do {
            #if DEBUG
            print("🌐 [Artwork]: \(url.absoluteString)")
            #endif
            let (data, _) = try await URLSession.shared.data(from: url)
            artworkCache.setObject(data as NSData, forKey: url as NSURL)
            return data
        } catch {
            #if DEBUG
            print("⚠️ Artwork download failed: \(error)")
            #endif
            return nil
        }
    }

    func searchForArtist(_ name: String, limit: Int = 1) async throws -> iTunesSearchResult? {
        let url = try iTunesSearchURL(term: name, entity: "musicArtist", extra: [
            URLQueryItem(name: "attribute", value: "artistTerm"),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        let response: iTunesSearchResponse = try await fetchITunesData(url: url)
        return response.results.first
    }

    func searchForArtists(_ name: String, limit: Int = 5) async throws -> [iTunesSearchResult] {
        let url = try iTunesSearchURL(term: name, entity: "musicArtist", extra: [
            URLQueryItem(name: "attribute", value: "artistTerm"),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        let response: iTunesSearchResponse = try await fetchITunesData(url: url)
        return response.results
    }

    func fetchArtistAlbums(artistId: Int) async throws -> [iTunesSearchResult] {
        let url = try iTunesLookupURL(id: artistId, entity: "album", limit: 30, sort: "recent")
        let response: iTunesSearchResponse = try await fetchITunesData(url: url)
        return response.results
            .dropFirst()
            .filter {
                let name = ($0.collectionName ?? "").lowercased()
                return !name.contains("radio") && !name.contains("episode")
                    && !name.contains("mixed") && !name.contains("podcast")
                    && ($0.trackCount ?? 0) > 0
            }
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }

    func fetchTracksForAlbum(collectionId: Int) async throws -> [iTunesSearchResult] {
        let url = try iTunesLookupURL(id: collectionId, entity: "song")
        let response: iTunesSearchResponse = try await fetchITunesData(url: url)
        return response.results.filter { $0.wrapperType == "track" }
    }

    func fetchTracksForArtists(artistIds: [Int]) async throws -> [iTunesSearchResult] {
        let url = try iTunesLookupURL(ids: artistIds, entity: "song", limit: 20, sort: "recent")
        let response: iTunesSearchResponse = try await fetchITunesData(url: url)
        return response.results
            .filter { $0.wrapperType == "track" }
            .filter { $0.trackName?.localizedCaseInsensitiveContains("extended") ?? false }
    }
    
    // MARK: - Metadata Search
    func findTrackMetadata(parsedTitle: (title: String, mix: String?),
                           parsedArtists: [String]) async -> iTunesSearchResult? {
        // Construct search term: "Artist Title"
        let term = parsedArtists.prefix(1).joined(separator: "+") + "+" + parsedTitle.title
        
        // Search for songs
        guard let url = try? iTunesSearchURL(term: term, entity: "song", extra: [
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "attribute", value: "songTerm")
        ]) else { return nil }

        guard let response: iTunesSearchResponse = try? await fetchITunesData(url: url) else {
            return nil
        }
        
        // Filter: Title must match
        // Sort: Popularity or Release Date? iTunes returns by relevance usually.
        return response.results
            .filter { ($0.trackName ?? "").localizedCaseInsensitiveContains(parsedTitle.title) }
            .first
    }

    func fetchArtistImage(from pageURL: URL) async -> URL? {
        guard let (data, _) = try? await URLSession.shared.data(from: pageURL),
              let html = String(data: data, encoding: .utf8) else { return nil }

        let pattern = #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["'][^>]*>"#
        guard let regex  = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match  = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range  = Range(match.range(at: 1), in: html),
              let slash  = html[range].lastIndex(of: "/") else { return nil }

        let base = String(html[range][...slash])
        return URL(string: base + "500x500-999.jpg")
    }


    
    // MARK: iTunes URL Builders
    /// Builds an iTunes Search API URL. Replaces %20 with + per iTunes preference.
    func iTunesSearchURL(term: String, entity: String,
                         extra: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term",   value: term),
            URLQueryItem(name: "entity", value: entity)
        ] + extra

        guard let raw = components.url,
              let url = URL(string: raw.absoluteString.replacingOccurrences(of: "%20", with: "+"))
        else { throw APIError.invalidURL }
        return url
    }

    func iTunesLookupURL(id: Int, entity: String,
                         limit: Int? = nil, sort: String? = nil) throws -> URL {
        try iTunesLookupURL(ids: [id], entity: entity, limit: limit, sort: sort)
    }

    func iTunesLookupURL(ids: [Int], entity: String,
                         limit: Int? = nil, sort: String? = nil) throws -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "id",     value: ids.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "media",  value: "music")
        ]
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let sort  { items.append(URLQueryItem(name: "sort",  value: sort)) }
        components.queryItems = items
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    // MARK: Generic iTunes Fetch (with cache)
    func fetchITunesData<T: Decodable>(url: URL) async throws -> T {
        if let cached = iTunesResponseCache.object(forKey: url as NSURL) {
            if let decoded = try? Self.apiDecoder.decode(T.self, from: cached as Data) {
                return decoded
            }
        }

        #if DEBUG
        print("🌐 [iTunes]: \(url.absoluteString)")
        #endif

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        iTunesResponseCache.setObject(data as NSData, forKey: url as NSURL)

        do {
            return try Self.apiDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

