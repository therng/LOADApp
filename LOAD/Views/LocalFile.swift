import SwiftUI
import AVFoundation


struct LocalDocumentBrowser: View {
    @State private var files: [LocalFile] = []
    @State private var isLoadingFiles = false
    
    @EnvironmentObject var player: AudioPlayerService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Group {
                    if files.isEmpty && !isLoadingFiles {
                        emptyStateView
                    } else {
                        fileList
                    }
                }
            }
            .navigationTitle("Local Documents")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadDocuments)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadDocuments) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var fileList: some View {
        List {
            ForEach(files) { file in
                Button(action: {
                    handleFileTap(file)
                }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(isCurrentTrack(file) ? .blue : .primary)
                            
                            HStack(spacing: 8) {
                                Text(file.creationDate)
                                Text("•")
                                Text(file.size)
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isCurrentTrack(file) {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteFile)
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("ไม่พบไฟล์ใน Local Documents")
                .foregroundColor(.secondary)
        }
    }
    
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
                .frame(width: 40, height: 50)
            Image(systemName: "music.note")
                .foregroundColor(.blue)
                .font(.system(size: 18))
        }
    }

    private func isCurrentTrack(_ file: LocalFile) -> Bool {
        guard let current = player.currentTrack else { return false }
        // We used the file name as the Track.key when creating local tracks
        return current.key == file.url.lastPathComponent
    }

    private func handleFileTap(_ file: LocalFile) {
        let audioExtensions = ["mp3", "m4a", "wav"]
        guard audioExtensions.contains(file.url.pathExtension.lowercased()) else { return }
        
        // แก้ไขตรงนี้: ใส่ localURL เข้าไปด้วยเพื่อให้ Service รู้ว่าเป็นไฟล์ในเครื่อง
        let track = Track(
            artist: "Local Device",
            title: file.name,
            duration: 0,
            key: file.url.lastPathComponent,
            localURL: file.url // <--- เพิ่มบรรทัดนี้ครับ
        )
        
        player.playNow(track: track)
    }

    private func loadDocuments() {
        isLoadingFiles = true
        let fileManager = FileManager.default
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            let df = DateFormatter(); df.dateFormat = "d MMM yyyy"
            let bf = ByteCountFormatter(); bf.countStyle = .file
            
            self.files = contents.map { url in
                let attr = try? fileManager.attributesOfItem(atPath: url.path)
                return LocalFile(
                    url: url,
                    name: url.lastPathComponent,
                    size: bf.string(fromByteCount: attr?[.size] as? Int64 ?? 0),
                    creationDate: df.string(from: attr?[.creationDate] as? Date ?? Date())
                )
            }.sorted(by: { $0.name < $1.name })
        } catch {
            print("Error loading: \(error)")
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
