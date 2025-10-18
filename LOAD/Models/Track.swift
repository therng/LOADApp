import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: Int
    let artist: String
    let title: String
    let duration: String
    let download: URL
    let stream: URL
}
