import Foundation

struct Track: Identifiable, Codable, Hashable {
    let artist: String
    let title: String
    let duration: Int
    let key: String

    // MARK: - Helpers
    private static let downloadBaseURL = URL(string: "https://nplay.idmp3s.xyz")!
    private static let streamBaseURL = URL(string: "https://nplay.idmp3s.xyz/stream")!

    var id: String { key }

    var download: URL {
        Self.downloadBaseURL.appendingPathComponent(key)
    }

    var stream: URL {
        Self.streamBaseURL.appendingPathComponent(key)
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
    let results: [Track]
    let query: String
    let count: Int
}

// MARK: - History Item

struct HistoryItem: Codable {
    let timestamp: Date
    let search_id: String
    let query: String
}
extension TimeInterval {
    /// Formats a time interval (seconds) as m:ss
    var mmss: String {
        let total = Int(self)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

