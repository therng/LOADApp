import SwiftUI

struct PlayerBackgroundView: View {
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        ZStack {
            if let artwork = player.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode:.fill)
                    .blur(radius: 35 , opaque: false)
            } else {
                Rectangle()
                    .fill(player.dominantColor ?? Color.clear)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    let player: AudioPlayerService = {
        let service = AudioPlayerService()
        let track = Track(
            artist: "Daxson",
            title: "Gravity",
            duration: 120,
            key: "preview",
            releaseDate: "2024"
        )
        service.setQueue([track])
        return service
    }()
    return PlayerBackgroundView()
        .environmentObject(player)
}
