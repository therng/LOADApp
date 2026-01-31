import Foundation
import UIKit

@MainActor
final class APIService {
    
    static let shared = APIService()
    
    // MARK: - Endpoint
    private let endpointBase =
    "https://postauditory-unmanoeuvred-lizette.ngrok-free.dev"

    // MARK: - Endpoint Builder
    private enum Endpoint {
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
                components.queryItems = [
                    URLQueryItem(name: "track", value: query)
                ]
                
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
                
            case .beatportID(let artist, let title, let mix):
                components.path = "/beatport"
                let queryItems = [
                    URLQueryItem(name: "artist", value: artist),
                    URLQueryItem(name: "title", value: title),
                    URLQueryItem(name: "mix", value: mix)
                    ]
                components.queryItems = queryItems
            }
            
            guard let url = components.url else {
                throw APIError.invalidURL
            }
            return url
        }
    }
    
    private init() {}
    
    // MARK: - URLSession
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Errors
    enum APIError: LocalizedError {
        case invalidURL
        case badResponse(statusCode: Int)
        case decodingError
        case network(Error)
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid request URL."
            case .badResponse(let status):
                return "Server error (\(status))."
            case .decodingError:
                return "Unable to read server data."
            case .network(let err):
                return err.localizedDescription
            case .cancelled:
                return "Request cancelled."
            }
        }
    }
    
    struct DeleteResponse: Decodable {
        let deleted_count: Int
    }
    struct DeleteItemResponse: Decodable {
        let deleted: Bool
        let search_id: String
    }
    
    struct BeatportResponse: Decodable {
        let track_id: Int
    }

    private var currentSearchTask: Task<SearchResponse, Error>?
    
    // MARK: - Warmup
    func warmUp() async {
        do {
            let url = try Endpoint.health.url(base: endpointBase)
            _ = try await session.data(from: url)
        } catch {
#if DEBUG
            Swift.print("🔥 Warmup failed:", error.localizedDescription)
#endif
        }
    }

    // MARK: - Search
    func search(query: String) async throws -> (searchId: String, tracks: [Track]) {
        // Cancel previous search task
        currentSearchTask?.cancel()

        let task = Task<SearchResponse, Error> {
            let url = try Endpoint.search(query: query).url(base: endpointBase)
            return try await request(url: url)
        }
        currentSearchTask = task
        
        do {
            let response = try await task.value
            
            return (response.search_id, response.results)
            
        } catch is CancellationError {
            throw APIError.cancelled
        }
    }

    // MARK: - Track Lookup
    func fetchTrack(key: String) async throws -> Track {
        let url = try Endpoint.track(key: key).url(base: endpointBase)
        return try await request(url: url)
    }
    
    // MARK: - History
    func fetchHistory() async throws -> [HistoryItem] {
        let url = try Endpoint.history.url(base: endpointBase)
        return try await request(url: url)
    }
    
    func fetchHistoryItem(with id: String) async throws -> SearchResponse {
        let url = try Endpoint.historyItem(id: id).url(base: endpointBase)
        return try await request(url: url)
    }
    
    // MARK: - Delete History
    func deleteAllHistoryItems() async throws -> Int {
        let url = try Endpoint.deleteAll.url(base: endpointBase)
        let response: DeleteResponse = try await request(url: url, method: "DELETE")
        return response.deleted_count
    }

    func deleteHistoryItem(with id: String) async throws -> Bool {
        let url = try Endpoint.deleteItem(id: id).url(base: endpointBase)
        let response: DeleteItemResponse = try await request(url: url, method: "DELETE")
        return response.deleted
    }
    
    // MARK: - Beatport Track ID Lookup
    
    /// Fetches the Beatport Track ID.
    /// - Parameters:
    ///   - artist: The artist name.
    ///   - title: The track title. If `mix` is nil, this title will be parsed to extract a mix.
    ///   - mix: Optional mix name. If provided, parsing is skipped.
    func beatportTrackID(artist: String, title: String, mix: String? = nil) async throws -> Int {
        let finalTitle: String
        let finalMix: String?
        
        if let mix = mix {
            finalTitle = title
            finalMix = mix.isEmpty ? nil : mix
        } else {
            let parsed = title.parseTitleAndMix()
            finalTitle = parsed.title
            finalMix = parsed.mix
        }
        
        let url = try Endpoint.beatportID(artist: artist, title: finalTitle, mix: finalMix).url(base: endpointBase)
        let response: BeatportResponse = try await request(url: url)
        return response.track_id
    }
    
    // MARK: - Core Request
    private func request<T: Decodable>(
        url: URL,
        method: String = "GET"
    ) async throws -> T {
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
#if DEBUG
        Swift.print("🌐 [API Request] \(method): \(url.absoluteString)")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            Swift.print("  Headers: \(headers)")
        }
#endif
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(statusCode: -1)
            }
            
            guard (200...299).contains(http.statusCode) else {
#if DEBUG
                if let body = String(data: data, encoding: .utf8) {
                    Swift.print("❌ HTTP \(http.statusCode):", body)
                }
#endif
                throw APIError.badResponse(statusCode: http.statusCode)
            }
            
            do {
                return try JSONDecoder.customDateDecoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
            
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let api as APIError {
            throw api
        } catch {
            throw APIError.network(error)
        }
    }
    
    
    // MARK: - Artwork Fetching
    
    private let artworkCache = NSCache<NSURL, NSData>()
    private let iTunesResponseCache = NSCache<NSURL, NSData>()
    
    public static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
    
    /// Fetches artwork and release date from the iTunes Search API for a given track and returns an updated track.
    public func fetchArtwork(for track: Track) async -> Track {
        // If we already have both pieces of information, we don't need to fetch again.
        guard track.artworkURL == nil || track.releaseDate == nil else { return track }
        
        var updatedTrack = track
        if let artworkInfo = await findArtwork(for: track) {
            updatedTrack.artworkURL = artworkInfo.artworkURL
            if let date = artworkInfo.releaseDate {
                updatedTrack.releaseDate = APIService.yearFormatter.string(from: date)
            }
        }
        return updatedTrack
    }

    func fetchArtworkData(for track: Track) async -> Data? {
        // First, ensure we have a URL to work with.
        guard let url = track.artworkURL else {
            // If the track doesn't have a URL, try finding one first.
            let updatedTrack = await fetchArtwork(for: track)
            // If a URL was found, call this function again with the updated track.
            if updatedTrack.artworkURL != nil {
                return await fetchArtworkData(for: updatedTrack)
            }
            // Otherwise, we can't proceed.
            return nil
        }
        
        // Check the cache before downloading.
        if let cachedData = artworkCache.object(forKey: url as NSURL) {
            return cachedData as Data
        }
        
        // If not in cache, download the data.
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Store the downloaded data in the cache.
            artworkCache.setObject(data as NSData, forKey: url as NSURL)
            return data
        } catch {
            // Use #if DEBUG to only print errors during development
#if DEBUG
            Swift.print("Error fetching artwork data: \(error)")
#endif
            return nil
        }
    }
    
    /// Fetches the artwork image and returns the updated track (with metadata) and the image.
    func fetchArtworkImage(for track: Track) async -> (updatedTrack: Track, image: UIImage?) {
        let updatedTrack = await fetchArtwork(for: track)
        if let data = await fetchArtworkData(for: updatedTrack),
           let image = UIImage(data: data) {
            return (updatedTrack, image)
        }
        return (updatedTrack, nil)
    }

    private func findArtwork(for track: Track) async -> (artworkURL: URL?, releaseDate: Date?)? {
        let parsedTitle = track.title.parseTitleAndMix()
        let parsedArtist = track.artist.replacingOccurrences(of: "Local File", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "-,")))
        let query = "\(parsedArtist) \(parsedTitle.title)"
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "media", value: "music")
            
        ]
        
        // URLComponents encodes spaces as %20, but the iTunes API prefers '+' for spaces.
        guard let tempUrl = components.url,
              let url = URL(string: tempUrl.absoluteString.replacingOccurrences(of: "%20", with: "+")) else {
            return nil
        }
        
        #if DEBUG
        Swift.print("🌐 [Artwork Request]: \(url.absoluteString)")
        #endif
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let response = try JSONDecoder.customDateDecoder.decode(iTunesSearchResponse.self, from: data)
            
            // Filter results based on the specified criteria.
            let filteredResults = response.results.filter {
                $0.collectionName?.localizedCaseInsensitiveContains(parsedTitle.title) ?? false
            }

            // Sort the filtered results by release date to find the earliest (original) version.
            guard let firstResult = filteredResults.sorted(by: { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }).first else {
                return nil
            }
            
            let releaseDate = firstResult.releaseDate
            var highResURL: URL?
            
            if let artworkURL = firstResult.artworkUrl100 {
                // Modify URL for higher resolution artwork
                let highResURLString = artworkURL.absoluteString.replacingOccurrences(of: "100x100", with: "500x500")
                highResURL = URL(string: highResURLString)
            }
            
            return (artworkURL: highResURL, releaseDate: releaseDate)
            
        } catch {
            // Don't log errors as this is an optional enhancement
            return nil
        }
    }
    
    // MARK: - Generic iTunes Request
    private func fetchITunesData<T: Decodable>(url: URL) async throws -> T {
        // Check cache
        if let cachedData = iTunesResponseCache.object(forKey: url as NSURL) {
            do {
                return try JSONDecoder.customDateDecoder.decode(T.self, from: cachedData as Data)
            } catch {
                #if DEBUG
                print("⚠️ [iTunes Cache] Decoding failed, re-fetching.")
                #endif
            }
        }
        
        #if DEBUG
        Swift.print("🌐 [iTunes Request]: \(url.absoluteString)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        // Cache data
        iTunesResponseCache.setObject(data as NSData, forKey: url as NSURL)
        
        do {
            return try JSONDecoder.customDateDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    // MARK: - iTunes Search
    func searchForArtist(_ artistName: String) async throws -> iTunesSearchResult? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: artistName),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "musicArtist"),
            URLQueryItem(name: "attribute", value: "artistTerm"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let tempUrl = components.url,
              let url = URL(string: tempUrl.absoluteString.replacingOccurrences(of: "%20", with: "+")) else {
            throw APIError.invalidURL
        }
        
        let searchResponse: iTunesSearchResponse = try await fetchITunesData(url: url)
        return searchResponse.results.first
    }

    func searchForArtistAlbums(_ artistName: String) async throws -> [iTunesSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: artistName),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "attribute", value: "artistTerm"),
            URLQueryItem(name: "limit", value: "200")
        ]
        
        guard let tempUrl = components.url,
              let url = URL(string: tempUrl.absoluteString.replacingOccurrences(of: "%20", with: "+")) else {
            throw APIError.invalidURL
        }
        
        let searchResponse: iTunesSearchResponse = try await fetchITunesData(url: url)
        
        let filteredResults = searchResponse.results.filter { result in
            // Only include albums with less than 10 tracks
            return (result.trackCount ?? 0) <= 6
        }
        
        // Sort by release date, newest first
        return filteredResults.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }
    
    // MARK: - Web Scraping for Artist Image
    func fetchArtistArtworkURL(from artistURL: URL) async -> URL? {
        do {
            let (data, _) = try await URLSession.shared.data(from: artistURL)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // Regex to find the <meta property="og:image" ... > tag and extract its content.
            // This is more robust as it handles other attributes and single/double quotes.
            let regex = try NSRegularExpression(pattern: "<meta[^>]+property=[\\\"']og:image[\\\"'][^>]+content=[\\\"']([^\\\"']+)[\"'][^>]*>", options: .caseInsensitive)
            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            guard let match = regex.firstMatch(in: html, options: [], range: range) else {
                return nil
            }

            // Extract the URL from the content attribute (capture group 1).
            guard let contentRange = Range(match.range(at: 1), in: html) else {
                return nil
            }
            let originalURLString = String(html[contentRange])

            // Per documentation, replace the filename to get a high-resolution version.
            guard let lastSlashIndex = originalURLString.lastIndex(of: "/") else {
                return URL(string: originalURLString) // Return original if format is unexpected.
            }
            
            let baseURL = originalURLString[...lastSlashIndex]
            let highResURLString = String(baseURL) + "10000x10000-999.jpg"
            
            return URL(string: highResURLString)

        } catch {
            #if DEBUG
            print("Failed to fetch or parse artist page for artwork: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - iTunes Lookup
    func fetchArtistAlbums(artistId: Int) async throws -> [iTunesSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(artistId)),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "200")
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        let searchResponse: iTunesSearchResponse = try await fetchITunesData(url: url)
        // The lookup returns the artist as the first result, followed by albums.
        // We drop the first result and sort the remaining albums by release date.
        let albums = searchResponse.results.dropFirst().filter { ($0.trackCount ?? 0) > 5 }
        return Array(albums).sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }

    func fetchTracksForAlbum(collectionId: Int) async throws -> [iTunesSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(collectionId)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "media", value: "music")
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        let searchResponse: iTunesSearchResponse = try await fetchITunesData(url: url)
        // Filter out the first result which is the collection itself, and sort by track number
        return searchResponse.results
            .filter { $0.wrapperType == "track" }
            .sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
    }
    
    func fetchTracksForArtists(artistIds: [Int]) async throws -> [iTunesSearchResult] {
        let idString = artistIds.map(String.init).joined(separator: ",")
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: idString),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "sort", value: "recent")
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        let searchResponse: iTunesSearchResponse = try await fetchITunesData(url: url)
        // Filter out any non-track results (like the artist objects themselves)
        return searchResponse.results.filter { $0.wrapperType == "track" }
    }
}



private extension JSONDecoder {
    
    static let customDateDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            let iso8601WithFractional: ISO8601DateFormatter = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }()
            
            if let date = iso8601WithFractional.date(from: string) {
                return date
            }
            
            let iso8601NoFractional: ISO8601DateFormatter = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }()
            
            if let date = iso8601NoFractional.date(from: string) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }()
}
