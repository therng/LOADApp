import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: Int
    let artist: String
    let title: String
    let duration: Int
    let download: URL
    let stream: URL

    // MARK: - Helpers
    var durationText: String {
        let minutes = duration / 60
        let seconds = duration % 60
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
