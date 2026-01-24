import SwiftUI
import AVFoundation
import Combine

struct LocalDocumentBrowser: View {
    @StateObject private var documentManager = LocalDocumentManager()
    
    @EnvironmentObject var player: AudioPlayerService
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 4) {
                if documentManager.files.isEmpty && !documentManager.isLoadingFiles {
                    emptyStateView
                } else {
                    fileList
                }
            }
            .navigationTitle("Local Files")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                 documentManager.loadDocuments()
            }
            .onAppear {
                // Initial load handled by manager init, but we check here too
                if documentManager.files.isEmpty {
                    documentManager.loadDocuments()
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var fileList: some View {
        List {
            ForEach(documentManager.files) { file in
                Button(action: { handleFileTap(file) }) {
                    HStack(spacing: 16) {
                        fileIcon

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundColor(isCurrentTrack(file) ? .accentColor : .primary)
                            
                            HStack(spacing: 8) {
                                Text(file.creationDate)
                                Text("•")
                                Text(file.size)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                                            
                        if isCurrentTrack(file) {
                           RealtimeAudioWaveView()
                      
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .onDelete(perform: deleteFile)
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Files Found in LOAD Folder")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Add files using the Files app or Finder")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 35, height: 35)
            Image(systemName: "music.note")
                .foregroundColor(.accentColor)
                .font(.system(size: 22))
        }
    }

    private func isCurrentTrack(_ file: LocalFile) -> Bool {
        guard let current = player.currentTrack else { return false }
        // We used the file name as the Track.key when creating local tracks
        return current.key == file.url.lastPathComponent
    }

    private func handleFileTap(_ file: LocalFile) {
        let audioExtensions = ["mp3", "m4a", "wav", "flac", "aac"]
        guard audioExtensions.contains(file.url.pathExtension.lowercased()) else { return }
        
        Haptics.impact()
        
        let track = Track(
            artist: "Local File",
            title: file.name,
            duration: 0, // Duration will be loaded by the player
            key: file.url.lastPathComponent,
            localURL: file.url
        )
        
        player.setQueue([track])
    }

    private func deleteFile(at offsets: IndexSet) {
        offsets.forEach { index in
            let file = documentManager.files[index]
            if isCurrentTrack(file) {
                player.stop()
            }
            documentManager.deleteFile(file)
        }
    }
}

// MARK: - Document Manager
@MainActor
class LocalDocumentManager: ObservableObject {
    @Published var files: [LocalFile] = []
    @Published var isLoadingFiles = false
    
    private let fileMonitor = FileMonitor()
    
    init() {
        // Setup the monitor callback
        fileMonitor.onDidChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.loadDocuments()
            }
        }
        
        loadDocuments()
        fileMonitor.start()
    }
    
    func loadDocuments() {
        isLoadingFiles = true
        
        // Run I/O on a detached task to keep the Main Actor free
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            // Ensure directory exists
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                let df = DateFormatter(); df.dateStyle = .medium
                let bf = ByteCountFormatter(); bf.countStyle = .file
                
                let loadedFiles = contents
                    .filter { !$0.lastPathComponent.hasPrefix(".") } // Skip hidden files
                    .compactMap { url -> LocalFile? in
                        guard let attr = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
                        let creationDate = attr[.creationDate] as? Date ?? Date()
                        let size = attr[.size] as? Int64 ?? 0
                        
                        return LocalFile(
                            url: url,
                            name: url.lastPathComponent,
                            size: bf.string(fromByteCount: size),
                            creationDate: df.string(from: creationDate)
                        )
                    }
                    .sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
                
                await MainActor.run {
                    self.files = loadedFiles
                    self.isLoadingFiles = false
                }

            } catch {
                print("Error loading documents: \(error)")
                await MainActor.run {
                    self.isLoadingFiles = false
                }
            }
        }
    }
    
    func deleteFile(_ file: LocalFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            // Optimistic update
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files.remove(at: index)
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}

// MARK: - File Helper
/// A separate helper class to manage the low-level DispatchSource.
/// This avoids actor isolation issues in `deinit`.
private class FileMonitor {
    private var monitorSession: MonitorSession?
    private let queue = DispatchQueue(label: "com.loadapp.filemonitor", attributes: .concurrent)
    
    var onDidChange: (() -> Void)?
    
    func start() {
        guard monitorSession == nil else { return }
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        
        source.setEventHandler { [weak self] in
            self?.onDidChange?()
        }
        
        source.setCancelHandler {
            close(descriptor)
        }
        
        source.resume()
        monitorSession = MonitorSession(source: source)
    }
    
    func stop() {
        monitorSession = nil
    }
    
    deinit {
        // No explicit stop needed, monitorSession deinit handles cancellation safely
    }
}

/// Helper class to manage DispatchSource lifetime and cancellation
private final class MonitorSession {
    private let source: DispatchSourceFileSystemObject
    
    init(source: DispatchSourceFileSystemObject) {
        self.source = source
    }
    
    deinit {
        source.cancel()
    }
}

#Preview {
    NavigationStack {
        LocalDocumentBrowser()
            .environmentObject(AudioPlayerService.shared)
    }
}

