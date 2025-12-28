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
            // 1) Pull the beginning so the file has a valid header to decode.
            //    160kbps ≈ 20KB/s
            let bytesPerSecond: Int64 = 20_000
            let chunkSize: Int64 = bytesPerSecond * 20
            guard let data = try await fetchAudioSample(from: downloadURL, maxBytes: chunkSize) else {
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

    private static func fetchAudioSample(from url: URL, maxBytes: Int64) async throws -> Data? {
        var req = URLRequest(url: url)
        req.setValue("bytes=0-\(maxBytes - 1)", forHTTPHeaderField: "Range")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard !data.isEmpty else { return nil }

        if data.count > Int(maxBytes) {
            return Data(data.prefix(Int(maxBytes)))
        }
        return data
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
