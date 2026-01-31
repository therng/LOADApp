import SwiftUI


private struct AlbumGridItemView: View {
    let album: iTunesSearchResult
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            VStack {
                AsyncImage(url: album.highResArtworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                                .font(.largeTitle)
                        }
                }
                .aspectRatio(1, contentMode: .fill)
                .cornerRadius(8)
                .shadow(radius: 3)
                
                Text(album.collectionName ?? "Untitled Album")
                    .font(.system(size: 13, weight: .regular, design:.default))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text(album.releaseDate.map { APIService.yearFormatter.string(from: $0) } ?? "—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}


struct ArtistDetailView: View {
    let artistId: Int
    let artistName: String
    
    @State private var albums: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Grid layout configuration
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 150))
    ]

    var body: some View {
        ZStack {
            contentView
                .task {
                    await loadArtistAlbums()
                }
        }
        .navigationTitle(artistName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
        } else if let message = errorMessage {
            ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if albums.isEmpty {
            ContentUnavailableView("No Albums Found", systemImage: "music.mic", description: Text("There were no albums found for \(artistName) on the iTunes Store."))
        } else {
            albumGridView
        }
    }
    
    private var albumGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 25) {
                ForEach(albums) { album in
                    AlbumGridItemView(album: album)
                }
            }
            .padding()
        }
    }
    
    private func loadArtistAlbums() async {
        do {
            isLoading = true
            let searchResults = try await APIService.shared.fetchArtistAlbums(artistId: artistId)
            self.albums = searchResults
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}


#Preview {
    NavigationStack {
        // Example ID for "Marlo" or similar
        ArtistDetailView(artistId: 261899, artistName: "Marlo")
    }
    .environmentObject(AudioPlayerService.shared)
}
