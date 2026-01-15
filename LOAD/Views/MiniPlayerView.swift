import SwiftUI

struct MiniPlayerView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var tabViewBottomAccessoryPlacement
    @EnvironmentObject var player: AudioPlayerService
    @Binding var isFullPlayerPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            switch tabViewBottomAccessoryPlacement {
            case .expanded:
                expandedView
            default:
                minimizedView
            }
        }
        .background(.clear)
        .buttonStyle(.glass)
        .onTapGesture {
            if player.currentTrack != nil {
                isFullPlayerPresented = true
            }
        }
    }

    // MARK: - Views
    
    @ViewBuilder
    private var expandedView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                artworkAndInfo
            
                titleView
            
                Spacer()
                
                playbackControls()
            }
            .frame(height: 60)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var minimizedView: some View {
        HStack(spacing: 5) {
            artworkAndInfo
        
            titleView
            
            Spacer(minLength: 5)
            
            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var titleView: some View {
        if let track = player.currentTrack {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text("Not Playing")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var artworkAndInfo: some View {
        if player.currentTrack != nil {
            ZStack {
                if let artwork = player.artworkImage {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 30, height: 30)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
            .clipped()
        } else {
            // Placeholder for when no track is playing
            ZStack {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
                    .foregroundColor(.secondary)
            }
            .frame(width: 30, height: 30)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
            .clipped()
        }
    }

    @ViewBuilder
    private func playbackControls() -> some View {
        HStack(spacing: 10) {
            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            
            Button(action: player.playNext) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 5)
    }
}

// MARK: - Previews

#Preview("Expanded") {
    let player = AudioPlayerService.shared
    player.setQueue([
        Track(artist: "Daft Punk", title: "Harder, Better, Faster, Stronger", duration: 224, key: "t1")
    ], startAt: 0)
    player.play()
    
    let view = MiniPlayerView(isFullPlayerPresented: .constant(false))
        .environmentObject(player)
    return view
}

#Preview("Minimized") {
    let player = AudioPlayerService.shared
    player.setQueue([
        Track(artist: "Daft Punk", title: "Harder, Better, Faster, Stronger", duration: 224, key: "t1")
    ], startAt: 0)
    player.play()
    
    let view = MiniPlayerView(isFullPlayerPresented: .constant(false))
        .environmentObject(player)
    return view
}

#Preview("No Track") {
    let player = AudioPlayerService() // A fresh instance
    let view = MiniPlayerView(isFullPlayerPresented: .constant(false))
        .environmentObject(player)
    return view
}
