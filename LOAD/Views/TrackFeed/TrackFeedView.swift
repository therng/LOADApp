import SwiftUI

struct TrackFeedView: View {
    @State private var viewModel = TrackFeedViewModel()
    @Environment(AudioPlayerService.self) var player
    @State private var showCopyBanner = false
    @State private var isPressing = false
    var body: some View {
            NavigationStack {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    } else if viewModel.sortedTracks.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 15) {
                                ForEach(viewModel.sortedTracks) { item in
                                    let track = makeTrack(from: item)
                                    TrackRow(
                                        track: track,
                                        isDimmed: item.previewURL == nil,
                                        onPlay: { playPreview(track: track) },
                                        onCopy: { copyToClipboard(track: track) }
                                    )
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Singles & EPs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(TrackSortOption.allCases) { option in
                                Button {
                                    Haptics.selection()
                                    if viewModel.sortOption == option {
                                        viewModel.isAscending.toggle()
                                    } else {
                                        viewModel.sortOption = option
                                        viewModel.isAscending = true
                                    }
                                } label: {
                                    Label(option.displayName(isActive: viewModel.sortOption == option, isAscending: viewModel.isAscending), systemImage: option.systemIcon)
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.sortOption.systemIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .contentShape(.circle)
                            
                        }
                    }
                }
                .refreshable {
                    viewModel.fetchLatestTracks()
                }
                .task {
                    viewModel.fetchLatestTracks()
                }
                .padding(.horizontal)
                .overlay(alignment: .bottom) {
                    if showCopyBanner {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Copied to clipboard")
                                .font(.subheadline.bold())
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                    }
                }
            }
        }
        
        private var emptyStateView: some View {
            ContentUnavailableView(
                "No Recent Tracks",
                systemImage: "music.note.list",
                description: Text("Follow some artists to see their latest tracks here.")
            )
        }
        
        private func makeTrack(from item: iTunesSearchResult) -> Track {
            Track(
                artist: item.artistName,
                title: item.trackName ?? "Unknown",
                duration: (item.trackTimeMillis ?? 0) / 1000,
                key: String(item.trackId ?? 0),
                localURL: nil,
                artworkURL: item.artworkURL,
                releaseDate: APIService.yearFormatter.string(from: item.releaseDate),
                customStreamURL: item.previewURL
            )
        }
        
        private func playPreview(track: Track) {
            guard track.customStreamURL != nil else { return }
            Haptics.impact()
            
            // Stop if playing the same track
            if let current = player.currentTrack, current.key == track.key, player.isPlaying {
                player.pause()
                return
            }
            
            // Use sorted tracks for the queue context
            let playableTracks = viewModel.sortedTracks.compactMap { makeTrack(from: $0) }.filter { $0.customStreamURL != nil }
            
            if let index = playableTracks.firstIndex(where: { $0.key == track.key }) {
                player.setQueue(playableTracks, startAt: index)
            }
        }
        
        private func copyToClipboard(track: Track) {
            let textToCopy = "\(track.artist) - \(track.title)"
            UIPasteboard.general.string = textToCopy
            Haptics.notify(.success)
            
            withAnimation {
                showCopyBanner = true
            }
            
            // Hide after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showCopyBanner = false
                }
            }
        }
    }


#Preview {
    TrackFeedView()
        .environment(AudioPlayerService())
}
