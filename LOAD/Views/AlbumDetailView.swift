import SwiftUI

struct AlbumDetailView: View {
    let album: iTunesSearchResult
    
    @State private var tracks: [iTunesSearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let message = errorMessage {
                ContentUnavailableView("Could Not Load", systemImage: "exclamationmark.triangle", description: Text(message))
            } else if tracks.isEmpty {
                ContentUnavailableView("No Tracks Found", systemImage: "music.mic", description: Text("No tracks were found for this album."))
            } else {
                List {
                    albumHeader
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical)

                    ForEach(tracks) { track in
                        HStack {
                            Text("\(track.trackNumber ?? 0).")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 25, alignment: .trailing)
                            Text(track.trackName ?? "Unknown Track")
                            Spacer()
                            Text(track.trackDuration ?? "--:--")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(album.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTracks()
        }
    }
    
    private var albumHeader: some View {
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
            .frame(width: 200, height: 200)
            .cornerRadius(8)
            .shadow(radius: 5)
            
            Text(album.collectionName)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text(album.artistName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadTracks() async {
        isLoading = true
        do {
            let searchResults = try await APIService.shared.fetchTracksForAlbum(album.collectionId)
            self.tracks = searchResults
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
