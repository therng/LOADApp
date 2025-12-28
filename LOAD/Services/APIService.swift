import Foundation

@MainActor
final class APIService {
    
    static let shared = APIService()
    
    // MARK: - Endpoint
    private let endpointBase =
    "https://postauditory-unmanoeuvred-lizette.ngrok-free.dev"
    
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

    private var currentSearchTask: Task<SearchResponse, Error>?
    
    // MARK: - Warmup
    func warmUp() async {
        guard let url = URL(string: "\(endpointBase)/health") else { return }
        do {
            _ = try await session.data(from: url)
        } catch {
#if DEBUG
            print("🔥 Warmup failed:", error.localizedDescription)
#endif
        }
    }
    
    // MARK: - Search (MAIN)
    func search(query: String) async throws -> SearchResponse {
        
        // Cancel previous search (สำคัญมาก)
        currentSearchTask?.cancel()
        
        let task = Task<SearchResponse, Error> {
            guard let encoded = query
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "\(endpointBase)/search?track=\(encoded)")
            else {
                throw APIError.invalidURL
            }
            
            return try await request(url: url)
        }
        
        currentSearchTask = task
        
        do {
            return try await task.value
        } catch is CancellationError {
            throw APIError.cancelled
        }
    }

    func searchTracks(query: String) async throws -> [Track] {
        let response = try await search(query: query)
        return response.results
    }
    
    // MARK: - History
    func fetchHistory() async throws -> [HistoryItem] {
        guard let url = URL(
            string: "\(endpointBase)/history"
        ) else {
            throw APIError.invalidURL
        }
        return try await request(url: url)
    }
    
    func fetchSearchResult(id: String) async throws -> SearchResponse {
        guard let url = URL(
            string: "\(endpointBase)/history/\(id)"
        ) else {
            throw APIError.invalidURL
        }
        return try await request(url: url)
    }
    
    // MARK: - Delete History
    func deleteAllHistory() async throws -> DeleteResponse {
        guard let url = URL(string: "\(endpointBase)/delete") else {
            throw APIError.invalidURL
        }
        return try await request(url: url, method: "DELETE")
    }

    func deleteHistoryItem(id: String) async throws -> DeleteItemResponse {
        guard let url = URL(string: "\(endpointBase)/delete/\(id)") else {
            throw APIError.invalidURL
        }
        return try await request(url: url, method: "DELETE")
    }
    
    // MARK: - Core Request (Generic, method)
    private func request(url: URL, method: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

#if DEBUG
        print("🌐 \(method):", url.absoluteString)
#endif
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(statusCode: -1)
            }
            guard (200...299).contains(http.statusCode) else {
#if DEBUG
                print("❌ HTTP \(http.statusCode) for \(method) \(url.absoluteString)")
#endif
                throw APIError.badResponse(statusCode: http.statusCode)
            }
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.network(error)
        }
    }
    
    // MARK: - Core Request (Decoding, method)
    private func request<T: Decodable>(url: URL, method: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

#if DEBUG
        print("🌐 \(method):", url.absoluteString)
#endif
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(statusCode: -1)
            }
            guard (200...299).contains(http.statusCode) else {
#if DEBUG
                if let body = String(data: data, encoding: .utf8) {
                    print("❌ HTTP \(http.statusCode):", body)
                }
#endif
                throw APIError.badResponse(statusCode: http.statusCode)
            }
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let api as APIError {
            throw api
        } catch {
            throw APIError.network(error)
        }
    }
    
    // MARK: - Core Request
    private func request<T: Decodable>(url: URL) async throws -> T {
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
#if DEBUG
        print("🌐 GET:", url.absoluteString)
#endif
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw APIError.badResponse(statusCode: -1)
            }
            
            guard (200...299).contains(http.statusCode) else {
#if DEBUG
                if let body = String(data: data, encoding: .utf8) {
                    print("❌ HTTP \(http.statusCode):", body)
                }
#endif
                throw APIError.badResponse(statusCode: http.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                
                if let date = APIService.iso8601WithFractional.date(from: string) {
                    return date
                }
                
                if let date = APIService.iso8601NoFractional.date(from: string) {
                    return date
                }

                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(string)"
                )
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
            
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.network(error)
        }
    }
    
    // MARK: - Date Decoding
    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    nonisolated(unsafe) private static let iso8601NoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

