import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let artist: String
    let title: String
    let duration: String
    let download: URL
    let stream: URL

    enum CodingKeys: String, CodingKey {
        case id, artist, title, duration, download, stream
    }
}

// MARK: - Convenience
extension Track {
    /// ใช้แสดงใน UI
    var formattedDuration: String {
        duration.isEmpty ? "0:00" : duration
    }

    /// แปลง "mm:ss" หรือ "hh:mm:ss" → วินาที (ไว้ให้ AudioPlayer / NowPlaying ใช้)
    var durationInSeconds: Double? {
        let parts = duration.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }

        if parts.count == 2 {
            // mm:ss
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            // hh:mm:ss
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        } else {
            return nil
        }
    }

    // MARK: - Sample Data (สำหรับ Preview / Dev)
    static let sample = Track(
        id: 1,
        artist: "Sample Artist",
        title: "Sample Track",
        duration: "3:30",
        download: URL(string: "https://example.com/download.mp3")!,
        stream: URL(string: "https://example.com/stream.mp3")!
    )

    static let samples: [Track] = [
        .sample,
        Track(
            id: 2,
            artist: "Another Artist",
            title: "Another Song",
            duration: "4:10",
            download: URL(string: "https://example.com/dl2.mp3")!,
            stream: URL(string: "https://example.com/st2.mp3")!
        ),
        Track(
            id: 3,
            artist: "Piano Solo",
            title: "Quiet Evening",
            duration: "2:58",
            download: URL(string: "https://example.com/dl3.mp3")!,
            stream: URL(string: "https://example.com/st3.mp3")!
        )
    ]
}
