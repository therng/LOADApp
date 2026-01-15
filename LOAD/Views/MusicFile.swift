//
//  MusicFile.swift
//  LOAD
//
//  Created by Supachai Thawatchokthavee on 14/1/26.
//


import SwiftUI
import UniformTypeIdentifiers

struct MusicFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let date: String
    let size: String
}

struct FilesAppBrowserView: View {
    @State private var isPickerPresented = false
    @State private var musicFiles: [MusicFile] = []
    @State private var folderName: String = "mp3" // ชื่อหัวข้อตามรูป

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List(musicFiles) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 16))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Text(file.date)
                                Text("-")
                                Text(file.size)
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                    
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text(folderName)
                            .font(.headline)
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPickerPresented = true }) {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result: result)
            }
        }
    }

    private func handleFolderSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            if folderURL.startAccessingSecurityScopedResource() {
                defer { folderURL.stopAccessingSecurityScopedResource() }
                folderName = folderURL.lastPathComponent
                scanFiles(in: folderURL)
            }
        case .failure(let error):
            print(error.localizedDescription)
        }
    }

    private func scanFiles(in url: URL) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            let formatter = DateFormatter()
            formatter.dateFormat = "d/M/yy"
            
            self.musicFiles = contents.filter { $0.pathExtension.lowercased() == "mp3" || $0.pathExtension.lowercased() == "vip" }.map { fileURL in
                let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
                let sizeInBytes = attributes?[.size] as? Int64 ?? 0
                let sizeString = ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
                let creationDate = attributes?[.creationDate] as? Date ?? Date()
                
                return MusicFile(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    date: formatter.string(from: creationDate),
                    size: sizeString
                )
            }
        } catch {
            print(error)
        }
    }
}
