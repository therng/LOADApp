import SwiftUI


struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    
    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    .purple.opacity(0.8), .blue.opacity(0.8), .cyan.opacity(0.8),
                    .pink.opacity(0.8), .indigo.opacity(0.8), .blue.opacity(0.8),
                    .red.opacity(0.8), .purple.opacity(0.8), .pink.opacity(0.8)
                ]
            )
            .ignoresSafeArea()
          
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    
                    Text("Now Playing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Menu {
                        if let track = player.currentTrack {
                            TrackActionMenuItems(track: track) { url in
                                safariURL = url
                            }
                        } else {
                            Button("No Track", systemImage: "music.note") {}
                                .disabled(true)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Large artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.1))
                        .frame(width: 300, height: 300)
                    
                    if let coverURL = player.currentCoverURL {
                        AsyncImage(url: coverURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image(systemName: "music.note")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.white.opacity(0.6))
                            default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                
                // Track info
                if let track = player.currentTrack {
                    VStack(spacing: 8) {
                        Text(track.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(track.artist)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal)
                }
                
                // Progress slider
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    .tint(.white)
                    
                    HStack {
                        Text(player.currentTime.mmss)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(player.duration.mmss)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 32)
                
                // Controls
                HStack(spacing: 40) {
                    Button {
                        player.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                        // iOS 18: Scale effect
                            .symbolEffect(.bounce, value: player.isPlaying)
                    }
                    
                    Button {
                        player.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 40)
        }
        .sheet(
            isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )
        ) {
            if let safariURL {
                SafariView(url: safariURL)
                    .presentationDetents([.medium, .large], selection: $safariDetent)
                    .presentationDragIndicator(.visible)
            }
        }
        .task(id: player.currentTrack?.id) {
            if let track = player.currentTrack {
                player.requestCoverIfNeeded(for: track)
            }
        }
    }
}
