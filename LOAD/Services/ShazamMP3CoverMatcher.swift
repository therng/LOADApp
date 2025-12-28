import Foundation
import AVFoundation
import ShazamKit

@MainActor
final class ShazamMP3CoverMatcher: NSObject {
    static let shared = ShazamMP3CoverMatcher()

    private override init() {
        super.init()
    }

    // ใช้ MP3 (track.download) เพื่อหา cover URL เท่านั้น
    func matchCover(from downloadURL: URL, completion: @escaping (URL?) -> Void) {
        Task.detached(priority: .utility) {
            let coverURL = await Self.fetchCoverURL(from: downloadURL)
            await MainActor.run {
                completion(coverURL)
            }
        }
    }

    private static func fetchCoverURL(from downloadURL: URL) async -> URL? {
        do {
            // 1) หา total bytes แบบ robust:
            //    - ลอง HEAD ก่อน
            //    - ถ้าไม่ได้ ให้ยิง Range 0-0 แล้วอ่าน Content-Range
            let totalBytes = try await fetchTotalBytes(for: downloadURL)
            guard totalBytes > 0 else {
                return nil
            }

            // 2) โหลดประมาณ 20 วิแถว ๆ กลางไฟล์ (ประมาณคร่าว ๆ ก็พอ)
            //    160kbps ≈ 20KB/s
            let bytesPerSecond: Int64 = 20_000
            let chunkSize: Int64 = bytesPerSecond * 20

            let mid = totalBytes / 2
            let start = max(0, mid - chunkSize / 2)
            let end = min(totalBytes - 1, start + chunkSize)

            var req = URLRequest(url: downloadURL)
            req.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")

            let (data, _) = try await URLSession.shared.data(for: req)
            if data.isEmpty {
                return nil
            }

            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp3")
            try data.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }

            // 3) Shazam อ่านไฟล์ temp นี้ (ไม่เก็บถาวร)
            let matcher = ShazamSessionMatcher()
            return try await matcher.matchCover(for: tmp)
        } catch {
            return nil
        }
    }

    private static func fetchTotalBytes(for url: URL) async throws -> Int64 {
        // Try HEAD
        do {
            var head = URLRequest(url: url)
            head.httpMethod = "HEAD"
            let (_, resp) = try await URLSession.shared.data(for: head)
            if let http = resp as? HTTPURLResponse,
               let len = http.value(forHTTPHeaderField: "Content-Length"),
               let n = Int64(len),
               n > 0 {
                return n
            }
        } catch {
            // fallthrough
        }

        // Fallback: Range 0-0 to obtain Content-Range: "bytes 0-0/12345"
        var req = URLRequest(url: url)
        req.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        let (_, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse,
              let cr = http.value(forHTTPHeaderField: "Content-Range") else {
            return 0
        }

        // Parse ".../TOTAL"
        if let slash = cr.lastIndex(of: "/") {
            let totalStr = cr[cr.index(after: slash)...]
            return Int64(totalStr) ?? 0
        }
        return 0
    }
}

private final class ShazamSessionMatcher: NSObject, SHSessionDelegate {
    private let session = SHSession()
    private var continuation: CheckedContinuation<URL?, Never>?

    override init() {
        super.init()
        session.delegate = self
    }

    func matchCover(for fileURL: URL) async throws -> URL? {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat

        let frames = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }

        try file.read(into: buffer)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.session.matchStreamingBuffer(buffer, at: nil)
        }
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let continuation = continuation else { return }
        self.continuation = nil
        continuation.resume(returning: match.mediaItems.first?.artworkURL)
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        guard let continuation = continuation else { return }
        self.continuation = nil
        continuation.resume(returning: nil)
    }
}
