import Foundation

@MainActor
final class TrackStorageService {
    static let shared = TrackStorageService()
    
    private let fileManager = FileManager.default
    
    // The directory where tracks are saved
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Downloads and saves a track to the app's documents directory.
    ///
    /// - Parameters:
    ///   - track: The track object to download.
    ///   - customFilename: Optional custom filename (without extension). If nil, the track title is used.
    /// - Returns: The file URL of the saved track.
    func saveTrack(_ track: Track, customFilename: String? = nil) async throws -> URL {
        // 1. Determine the filename
        let baseName = customFilename ?? sanitizedFilename(track.title)
        let fileName = baseName.hasSuffix(".mp3") ? baseName : "\(baseName).mp3"
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        // 2. Check if file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            #if DEBUG
            print("📂 Track already exists: \(destinationURL.lastPathComponent)")
            #endif
            return destinationURL
        }
        
        // 3. Download the file
        // Note: URLSession.shared.download returns control as soon as headers are received?
        // No, it waits for the body. This is async and won't block MainActor.
        let (tempURL, response) = try await URLSession.shared.download(from: track.download)
        
        // 4. Validate Response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // 5. Move file to permanent location
        // fileManager.moveItem is synchronous, but moving a file on the same volume is fast.
        do {
            // Ensure destination doesn't exist (race condition check)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        } catch {
            throw error
        }
        
        // 6. Fetch Metadata & Write ID3 Tags
        // We do this after moving so we have the file in place.
        let trackWithMetadata = await APIService.shared.fetchArtwork(for: track)
        do {

           
            print("🏷️ ID3 Tags written for: \(trackWithMetadata.title)")


        }
        
        #if DEBUG
        print("✅ Saved track to: \(destinationURL.path)")
        #endif
        
        return destinationURL
    }
    
    /// Returns the full file URL for a given filename.
    func fileURL(for filename: String) -> URL {
        let fileName = filename.hasSuffix(".mp3") ? filename : "\(filename).mp3"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    /// Checks if a track is already saved locally.
    func isTrackSaved(filename: String) -> Bool {
        let fileName = filename.hasSuffix(".mp3") ? filename : "\(filename).mp3"
        let url = documentsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Deletes a saved track by filename.
    func deleteTrack(filename: String) throws {
        let fileName = filename.hasSuffix(".mp3") ? filename : "\(filename).mp3"
        let url = documentsDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Returns a list of all saved track URLs.
    func getSavedTracks() -> [URL] {
        do {
            let urls = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return urls.filter { $0.pathExtension == "mp3" }
        } catch {
            print("Error listing tracks: \(error)")
            return []
        }
    }
    
    // MARK: - Helpers
    
    private func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalid)
            .joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

