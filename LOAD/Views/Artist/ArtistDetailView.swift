import SwiftUI

private struct AlbumGridItemView: View {
    let album: iTunesSearchResult
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: album.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                                .font(.largeTitle)
                        }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.collectionName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(APIService.yearFormatter.string(from: album.releaseDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArtistDetailView: View {
    let artistId: Int
    let artistName: String
    
    @State private var albums: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isGridView = true
    
    // Grid layout configuration
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 160), spacing: 20)
    ]
    
    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long // e.g. February 16, 2026
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        ZStack {
            contentView
                .task {
                    await loadArtistAlbums()
                }
        }
        .navigationTitle(artistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isGridView.toggle() }
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(isGridView ? "Show as list" : "Show as grid")
            }
        }
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
            if isGridView {
                albumGridView
            } else {
                albumListView
            }
        }
    }
    
    private var albumGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(albums) { album in
                    AlbumGridItemView(album: album)
                }
            }
            .padding()
        }
        .refreshable {
            await loadArtistAlbums()
        }
    }
    
    private var albumListView: some View {
        List(albums) { album in
            NavigationLink(destination: AlbumDetailView(album: album)) {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: album.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 8))
                    .shadow(radius: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Line 1: Title
                        Text(album.collectionName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        // Line 2: Artist
                        Text(album.artistName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        // Line 3: Copyright
                        if !album.copyright.isEmpty {
                            Text(album.copyright)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        // Line 4: Track Count + Release Date
                        Text("\(album.trackCount ?? 0) tracks • \(formatDate(album.releaseDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
                .padding(.vertical, 4)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .refreshable {
            await loadArtistAlbums()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.longDateFormatter.string(from: date)
    }
    
    private func loadArtistAlbums() async {
        do {
            isLoading = true
            let searchResults = try await APIService.shared.fetchArtistAlbums(artistId: artistId)
            
            // Filter out duplicate results by ID to avoid ForEach/List crashes
            var uniqueResults = [iTunesSearchResult]()
            var seenIds = Set<Int>()
            for result in searchResults {
                if seenIds.insert(result.id).inserted {
                    uniqueResults.append(result)
                }
            }
            
            self.albums = uniqueResults
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview{
    NavigationView {
        ArtistDetailView(artistId: 481465908, artistName: "")
            .environment(AudioPlayerService.shared)
    }
}
