import SwiftUI

struct PlayerBackgroundView: View {
    @Environment(AudioPlayerService.self) var player

    var body: some View {
        ZStack {
            if let artwork = player.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 35, opaque: false)
            } else {
                Rectangle()
                    .fill(.clear)
            }
            
            LinearGradient(
                colors: [.black.opacity(0.6), .black.opacity(0.2), .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
