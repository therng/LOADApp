import SwiftUI


private struct AlbumGridItemView: View {
    let album: iTunesSearchResult
    let onCopy: () -> Void

    @State private var isPressing = false

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
    
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
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                .shadow(radius: 3)
                
                Text(album.collectionName)
                    .font(.system(size: 11, weight: .regular, design:.rounded))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text(Self.yearFormatter.string(from: album.releaseDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .scaleEffect(isPressing ? 1.15 : 1.0)
            .animation(.spring (response: 0.1, dampingFraction: 3), value: isPressing)
            .onLongPressGesture {
                onCopy()
                isPressing = false
            } onPressingChanged: { pressing in
                self.isPressing = pressing
            }
        }
    }
}


struct ArtistDetailView: View {
    let artistName: String
    
    @State private var albums: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopiedBanner = false
    
    // Grid layout configuration
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 100))
    ]

    var body: some View {
        ZStack {
            contentView
                .navigationTitle(artistName)
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    await loadArtistAlbums()
                }
            
            if showCopiedBanner {
                copiedBannerView
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
            albumGridView
        }
    }
    
    private var albumGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 25) {
                ForEach(albums) { album in
                    AlbumGridItemView(album: album) {
                        handleCopyAction(for: album)
                    }
                }
            }
            .padding()
        }
    }
    
    private var copiedBannerView: some View {
        VStack {
            HStack(spacing:2){
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Copied")
            }
            .font(.system(size: 14, weight: .semibold, design:.rounded))
            .frame(maxHeight:20)
            .padding(3)
            .background(.thinMaterial)
            .clipShape(.capsule)
            .shadow(radius: 5)
            .onTapGesture {
                withAnimation {
                    showCopiedBanner = false
                }
            }
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private func handleCopyAction(for album: iTunesSearchResult) {
        // Give haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Combine artist and album name for copying
        let textToCopy = "\(album.artistName) - \(album.collectionName)"
        
        // Set the string on the general pasteboard
        UIPasteboard.general.string = textToCopy
        
        // Trigger the banner animation
        withAnimation {
            showCopiedBanner = true
        }
        
        // Schedule the banner to disappear after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showCopiedBanner = false
            }
        }
    }
    
    private func loadArtistAlbums() async {
        do {
            isLoading = true
            let searchResults = try await APIService.shared.searchForArtistAlbums(artistName)
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
        ArtistDetailView(artistName: "Marlo")
    }
}
