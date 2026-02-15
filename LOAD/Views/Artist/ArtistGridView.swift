import SwiftUI

struct ArtistGridView: View {
    let viewModel: ArtistCollectionViewModel
    let columns: [GridItem]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                if !viewModel.pinnedArtists.isEmpty {
                    ForEach(viewModel.pinnedArtists) { artist in
                        ArtistGridItem(artist: artist, viewModel: viewModel)
                    }
                }
                
                if !viewModel.unpinnedArtists.isEmpty {
                    ForEach(viewModel.unpinnedArtists) { artist in
                        ArtistGridItem(artist: artist, viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
    }
}

private struct ArtistGridItem: View {
    let artist: Artist
    var viewModel: ArtistCollectionViewModel
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(artistId: artist.artistId, artistName: artist.artistName)) {
            ZStack(alignment: .bottomLeading) {
                artwork
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                Text(artist.artistName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .lineLimit(1)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 5)
        }
        .contextMenu {
            pinButton
            unfollowButton
        }
    }
    
    @ViewBuilder
    private var artwork: some View {
        if let url = artist.artistImage {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                case .empty:
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
    
    private var pinButton: some View {
        Button {
            withAnimation {
                viewModel.togglePin(for: artist)
            }
        } label: {
            Label(artist.isPinned ? "Unpin" : "Pin", systemImage: artist.isPinned ? "pin.slash.fill" : "pin.fill")
        }
        .tint(artist.isPinned ? .gray : .accentColor)
    }

    private var unfollowButton: some View {
        Button(role: .destructive) {
            withAnimation {
                viewModel.unfollow(artist: artist)
            }
        } label: {
            Label("Unfollow", systemImage: "person.crop.circle.badge.xmark")
        }
    }
}

#Preview {
    ArtistGridView(viewModel: ArtistCollectionViewModel(), columns: [GridItem()])
}

