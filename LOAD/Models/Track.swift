import Foundation

struct Track: Identifiable, Codable, Hashable {
    let artist: String
    let title: String
    let duration: Int
    let key: String
    
    // ฟิลด์สำหรับเก็บ Path ไฟล์ในเครื่อง (เพิ่มเข้าไปที่นี่ที่เดียว)
    var localURL: URL?

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

    // รวมศูนย์การเลือก URL สำหรับเล่นไว้ที่นี่
    var playURL: URL {
        if let local = localURL {
            return local
        }
        return stream
    }
//    func startAccessing() -> Bool {
//            guard let url = localURL else { return true } // ถ้าเป็น Stream ไม่ต้องขอสิทธิ์
//            return url.startAccessingSecurityScopedResource()
//        }
//        
//        /// ฟังก์ชันสำหรับปล่อยสิทธิ์การเข้าถึงไฟล์
//        func stopAccessing() {
//            localURL?.stopAccessingSecurityScopedResource()
//        }
    
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

// MARK: - Local File Model
struct LocalFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: String
    let creationDate: String
}
