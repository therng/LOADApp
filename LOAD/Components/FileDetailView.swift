import SwiftUI

struct FileDetailView: View {
    let fileURL: URL
    @Binding var isPresented: Bool
    
    @State private var attributes: [FileAttributeKey: Any] = [:]
    
    var body: some View {
        NavigationStack {
            List {
                Section("File Info") {
                    LabeledContent("Name", value: fileURL.lastPathComponent)
                    if let size = fileSize {
                        LabeledContent("Size", value: size)
                    }
                    if let date = creationDate {
                        LabeledContent("Created", value: date)
                    }
                    LabeledContent("Path", value: fileURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contextMenu {
                            Button("Copy Path") {
                                UIPasteboard.general.string = fileURL.path
                            }
                        }
                }
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            loadAttributes()
        }
    }
    
    private var fileSize: String? {
        guard let size = attributes[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private var creationDate: String? {
        guard let date = attributes[.creationDate] as? Date else { return nil }
        return date.formatted(date: .long, time: .shortened)
    }
    
    private func loadAttributes() {
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            print("Error loading attributes: \(error)")
        }
    }
}
