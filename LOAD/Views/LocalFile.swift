import SwiftUI
import AVFoundation

struct LocalDocumentBrowser: View {
    @State private var files: [LocalFile] = []
    @State private var isLoadingFiles = false
    
    @EnvironmentObject var player: AudioPlayerService
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 4) {
                if files.isEmpty && !isLoadingFiles {
                    emptyStateView
                } else {
                    fileList
                }
            }
            .navigationTitle("Local Files")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                 loadDocuments()
            }
            .onAppear {
                loadDocuments()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var fileList: some View {
        List {
            ForEach(files) { file in
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
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
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
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 50, height: 50)
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
        
        let track = Track(
            artist: "Local File",
            title: file.name,
            duration: 0, // Duration will be loaded by the player
            key: file.url.lastPathComponent,
            localURL: file.url
        )
        
        player.setQueue([track])
    }

    private func loadDocuments() {
        isLoadingFiles = true
        let fileManager = FileManager.default
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            let df = DateFormatter(); df.dateStyle = .medium
            let bf = ByteCountFormatter(); bf.countStyle = .file
            
            self.files = contents
                .compactMap { url in
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

        } catch {
            print("Error loading documents: \(error)")
        }
        isLoadingFiles = false
    }
    
    private func deleteFile(at offsets: IndexSet) {
        offsets.forEach { index in
            let file = files[index]
            if isCurrentTrack(file) {
                player.stop()
            }
            try? FileManager.default.removeItem(at: file.url)
        }
        files.remove(atOffsets: offsets)
    }
}

#Preview {
    NavigationStack {
        LocalDocumentBrowser()
            .environmentObject(AudioPlayerService.shared)
    }
}

