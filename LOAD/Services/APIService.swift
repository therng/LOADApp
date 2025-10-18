import Foundation

@MainActor
final class APIService {
    static let shared = APIService()
    private let endpointBase = "https://postauditory-unmanoeuvred-lizette.ngrok-free.dev"
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    enum APIError: LocalizedError {
        case invalidURL, badResponse, decodingError, networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid request URL."
            case .badResponse: return "Server returned an invalid response."
            case .decodingError: return "Failed to parse data."
            case .networkError(let err): return err.localizedDescription
            }
        }
    }

    // MARK: - API Response

    struct Response: Decodable {
        let songs: [TrackDTO]
    }

    struct TrackDTO: Decodable {
        let id: Int
        let artist: String
        let title: String
        let duration: String
        let download: String
        let stream: String

        func asTrack() -> Track? {
            guard let downloadURL = URL(string: download),
                  let streamURL = URL(string: stream) else { return nil }

            return Track(
                id: id,
                artist: artist,
                title: title,
                duration: duration,
                download: downloadURL,
                stream: streamURL
            )
        }
    }

    // MARK: - Public API

    func searchTracks(query: String) async throws -> [Track] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(endpointBase)/search?track=\(encoded)") else {
            throw APIError.invalidURL
        }

        let request = URLRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError.badResponse
            }

            #if DEBUG
            if let str = String(data: data, encoding: .utf8) {
                print("🔍 API Response:", str)
            }
            #endif

            let payload = try JSONDecoder().decode(Response.self, from: data)
            return payload.songs.compactMap { $0.asTrack() }

        } catch is DecodingError {
            throw APIError.decodingError
        } catch {
            throw APIError.networkError(error)
        }
    }
}
