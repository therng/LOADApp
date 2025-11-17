import Foundation

@MainActor
final class APIService {
    static let shared = APIService()
    private let endpointBase = "https://postauditory-unmanoeuvred-lizette.ngrok-free.dev"
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
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

    // MARK: - Warm-up

    func warmUp() async {
        guard let url = URL(string: "\(endpointBase)/health") ?? URL(string: "\(endpointBase)/") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            #if DEBUG
            print("🔥 Warm-up request:", request.url?.absoluteString ?? "nil")
            #endif
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                #if DEBUG
                print("🔥 Warm-up status:", http.statusCode)
                #endif
            }
        } catch {
            #if DEBUG
            print("🔥 Warm-up failed:", error.localizedDescription)
            #endif
        }
    }

    // MARK: - Public API

    func searchTracks(query: String) async throws -> [Track] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(endpointBase)/search?track=\(encoded)") else {
            #if DEBUG
            print("❌ API: invalidURL for query:", query)
            #endif
            throw APIError.invalidURL
        }

        let request = URLRequest(url: url)

        // Retry 2 ครั้ง (รวม 3 attempts) สำหรับ network error และ 5xx
        let maxAttempts = 3
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            attempt += 1
            do {
                #if DEBUG
                print("➡️ API Request [attempt \(attempt)]:", request.url?.absoluteString ?? "nil")
                #endif

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.badResponse
                }

                // ตรวจสอบสถานะ HTTP
                guard 200..<300 ~= http.statusCode else {
                    #if DEBUG
                    print("❌ API badResponse:", http.statusCode, http.url?.absoluteString ?? "")
                    if let str = String(data: data, encoding: .utf8) {
                        print("❌ API body:", str)
                    }
                    #endif

                    if (500...599).contains(http.statusCode), attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(300_000_000 * attempt)) // 0.3s, 0.6s
                        continue
                    }
                    throw APIError.badResponse
                }

                // ตรวจสอบ MIME type ต้องเป็น JSON
                let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                let isJSON = mime.contains("application/json") || mime.contains("text/json")

                // ตรวจสอบว่า body ไม่ใช่ HTML (ป้องกัน interstitial ของ ngrok)
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                let looksLikeHTML = bodyString.lowercased().contains("<html") ||
                                    bodyString.lowercased().contains("<!doctype html")

                if !isJSON || looksLikeHTML {
                    #if DEBUG
                    print("❌ API non-JSON or HTML interstitial detected. mime:", mime)
                    if !bodyString.isEmpty {
                        print("❌ Snippet:", String(bodyString.prefix(200)))
                    }
                    #endif
                    // ให้ถือว่าเป็น badResponse และลอง retry
                    if attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(300_000_000 * attempt))
                        continue
                    } else {
                        throw APIError.badResponse
                    }
                }

                #if DEBUG
                if !bodyString.isEmpty {
                    print("🔍 API Response:", bodyString)
                }
                #endif

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .useDefaultKeys

                let payload = try decoder.decode(Response.self, from: data)
                return payload.songs.compactMap { $0.asTrack() }

            } catch let error as DecodingError {
                #if DEBUG
                print("❌ API decodingError:", error)
                #endif
                throw APIError.decodingError
            } catch {
                lastError = error
                #if DEBUG
                print("❌ API networkError (attempt \(attempt)):", error.localizedDescription)
                #endif

                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(300_000_000 * attempt))
                    continue
                } else {
                    throw APIError.networkError(error)
                }
            }
        }

        throw APIError.networkError(lastError ?? URLError(.unknown))
    }
}
