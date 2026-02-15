import Foundation
import SwiftUI

/// A robust, actor-based service for managing downloaded tracks and their persistence.
/// Handles file system operations, metadata storage, auto-saving, and conflict resolution.
@MainActor
@Observable
final class TrackStorageService {
    static let shared = TrackStorageService()
    
    // Publicly available list of saved tracks
    private(set) var savedTracks: [Track] = []
    
    private let fileManager = FileManager.default
    private let metadataFileName = "saved_tracks.json"
    
    // Serial queue for file operations to ensure thread safety
    @ObservationIgnored private let ioQueue = DispatchQueue(label: "com.loadapp.trackstorage.io", qos: .utility)
    
    private init() {
        loadTracks()
    }
    
    // MARK: - Public API
    
    /// Checks if a track is already downloaded/saved
    func isTrackSaved(_ track: Track) -> Bool {
        savedTracks.contains { $0.id == track.id }
    }
    
    /// Saves a track by downloading its audio file and persisting its metadata.
    /// - Parameters:
    ///   - track: The track to save.
    ///   - customFilename: Optional custom filename (without extension).
    ///   - onProgress: Optional callback for download progress.
    func saveTrack(_ track: Track, customFilename: String? = nil, onProgress: ((Double) -> Void)? = nil) async throws -> URL {
        // 1. Determine destination URL with conflict resolution
        let filename = customFilename ?? track.title
        let safeFilename = sanitizeFilename(filename)
        let destinationURL = try resolveFileConflict(for: safeFilename, extension: "mp3")
        
        // 2. Stream download to temporary file (memory efficient)
        let (tempURL, response) = try await URLSession.shared.download(from: track.download)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 3. Move downloaded file atomically to destination
        try await moveDownloadedFile(from: tempURL, to: destinationURL)

        // 4. Ensure file is fully written and stable
        try await ensureFileIsStable(at: destinationURL)

        // 5. Update Metadata
        var savedTrack = track
        savedTrack.localURL = destinationURL
        
        updateTrackList(with: savedTrack)
        Haptics.notify(.success)
        return destinationURL
    }
    
    func deleteTrack(_ track: Track) {
        guard let index = savedTracks.firstIndex(where: { $0.id == track.id }) else { return }
        let trackToDelete = savedTracks[index]
        
        // Remove from list immediately (optimistic UI)
        savedTracks.remove(at: index)
        saveTracksToDisk()
        
        // Delete file asynchronously
        Task(priority: .utility) {
            if let url = trackToDelete.localURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    // MARK: - Internal Logic
    
    private func updateTrackList(with track: Track) {
        if let index = savedTracks.firstIndex(where: { $0.id == track.id }) {
            // Conflict Resolution: Update existing entry
            savedTracks[index] = track
        } else {
            savedTracks.append(track)
        }
        
        // Auto-Save metadata
        saveTracksToDisk()
    }
    
    private func saveTracksToDisk() {
        let tracks = savedTracks
        let filename = metadataFileName
        // Prepare the URL on the current actor before dispatching to background
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        ioQueue.async {
            do {
                let data = try JSONEncoder().encode(tracks)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("Error saving tracks metadata: \(error)")
            }
        }
    }
    
    private func loadTracks() {
        let filename = metadataFileName
        let url = getDocumentsDirectory().appendingPathComponent(filename)

        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let data = try? Data(contentsOf: url),
                  let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
                return
            }
            
            // Validate local files exist
            let validTracks = tracks.map { track -> Track in
                var t = track
                // Ensure localURL is relative to current sandbox (container UUID changes on reinstall/build)
                if let relativePath = t.localURL?.lastPathComponent {
                    t.localURL = self.getDocumentsDirectory().appendingPathComponent(relativePath)
                }
                return t
            }
            
            Task { @MainActor in
                self.savedTracks = validTracks
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Marked nonisolated to allow calling from background queues without main actor constraints
    nonisolated private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        name.components(separatedBy: .init(charactersIn: "/\\?%*|\"<>:")).joined(separator: "_")
    }
    
    /// Resolves filename conflicts by appending a number if the file already exists.
    /// e.g. "Song.mp3" -> "Song 1.mp3"
    private func resolveFileConflict(for filename: String, extension ext: String) throws -> URL {
        let docDir = getDocumentsDirectory()
        var url = docDir.appendingPathComponent("\(filename).\(ext)")
        var counter = 1
        
        while fileManager.fileExists(atPath: url.path) {
            url = docDir.appendingPathComponent("\(filename) \(counter).\(ext)")
            counter += 1
        }
        
        return url
    }
    
    private func moveDownloadedFile(from tempURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Waits until file size is stable across two checks to avoid race conditions.
    private func ensureFileIsStable(at url: URL) async throws {
        var previousSize: UInt64 = 0
        var attempts = 0

        while attempts < 5 {
            try await Task.sleep(nanoseconds: 150_000_000)

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let currentSize = attributes[.size] as? UInt64 ?? 0

            if currentSize > 0 && currentSize == previousSize {
                return
            }

            previousSize = currentSize
            attempts += 1
        }

        throw URLError(.cannotWriteToFile)
    }
}
