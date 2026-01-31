import SwiftUI

struct ArtistRowView: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: artist.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "music.mic")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.3))
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(artist.artistName)
                    .font(.headline)
                    .lineLimit(1)
                if let genre = artist.primaryGenreName {
                    Text(genre)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
