import SwiftUI

struct ArtistTabView: View {
    @StateObject private var viewModel = ArtistCollectionViewModel()

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.artists.isEmpty {
                    emptyStateView
                } else {
                    artistGridView
                }
            }
            .navigationTitle("Artists")
        }
    }

    private var artistGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                if !viewModel.pinnedArtists.isEmpty {
                    Section(header: sectionHeader("Pinned")) {
                        ForEach(viewModel.pinnedArtists) { artist in
                            artistGridItem(for: artist)
                        }
                    }
                }
                
                if !viewModel.unpinnedArtists.isEmpty {
                    Section(header: sectionHeader("Followed")) {
                        ForEach(viewModel.unpinnedArtists) { artist in
                            artistGridItem(for: artist)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    private func artistGridItem(for artist: Artist) -> some View {
        NavigationLink(destination: ArtistDetailView(artistId: artist.artistId, artistName: artist.artistName)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: artist.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "music.mic")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }
                
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
        }
        .contextMenu {
            pinButton(for: artist)
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

    private var emptyStateView: some View {
        VStack {
            Image(systemName: "music.mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("No Followed Artists")
                .font(.title2)
                .padding(.top)
            Text("Follow artists from the player or search to see them here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    ArtistTabView()
        .environmentObject(ArtistCollectionViewModel())
}
