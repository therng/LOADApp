import SwiftUI

struct ArtistListView: View {
    let viewModel: ArtistCollectionViewModel

    var body: some View {
        List {
            if !viewModel.pinnedArtists.isEmpty {
                Section("Pinned") {
                    ForEach(viewModel.pinnedArtists) { artist in
                        artistRowItem(for: artist)
                    }
                }
            }
            
            if !viewModel.unpinnedArtists.isEmpty {
                Section("All Artists") {
                    ForEach(viewModel.unpinnedArtists) { artist in
                        artistRowItem(for: artist)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func artistRowItem(for artist: Artist) -> some View {
        NavigationLink(destination: ArtistDetailView(artistId: artist.artistId, artistName: artist.artistName)) {
            HStack(spacing: 12) {
                AsyncImage(url: artist.artistImage) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .overlay {
                                if phase.error != nil {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .shadow(radius: 4)
                
                Text(artist.artistName)
                    .font(.headline)
                
                Spacer()
                
                if artist.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.tint)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.glass)
        .swipeActions(edge: .leading) {
            pinButton(for: artist)
        }
        .swipeActions(edge: .trailing) {
            unfollowButton(for: artist)
        }
    }
    
    private func pinButton(for artist: Artist) -> some View {
        Button {
            withAnimation {
                viewModel.togglePin(for: artist)
            }
        } label: {
            Label(artist.isPinned ? "Unpin" : "Pin", systemImage: artist.isPinned ? "pin.slash.fill" : "pin.fill")
        }
        .tint(artist.isPinned ? .gray : .accentColor)
    }

    private func unfollowButton(for artist: Artist) -> some View {
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
    ArtistListView(viewModel: ArtistCollectionViewModel())
}

