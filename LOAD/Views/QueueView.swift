import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: AudioPlayerService

    private var hasContent: Bool {
        player.currentTrack != nil || !player.upcomingTracks.isEmpty
    }

    var body: some View {
        List {
            if hasContent {
                nowPlayingSection
                nextUpSection
            } else {
                emptyState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .foregroundColor(.primary)
        .background(.clear)
        .tint(.blue)
        .scrollContentBackground(.hidden)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    player.shuffleUpcoming()
                } label: {
                    Image(systemName: "shuffle")
                }
                .disabled(player.upcomingTracks.count < 2)

                Button(role: .destructive) {
                    Haptics.impact(.medium)
                    player.clearUpcoming()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(player.upcomingTracks.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let track = player.currentTrack {
            Section("Now Playing") {
                TrackRow(track: track)
                    .listRowInsets(.init(top: 5, leading: 8, bottom: 5, trailing: 8))
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var nextUpSection: some View {
        if !player.upcomingTracks.isEmpty {
            Section("Next Up") {
                ForEach(Array(player.upcomingTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track)
                        .background(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.impact()
                            // Calculate absolute index in the main queue
                            let absoluteIndex = player.currentIndex + 1 + index
                            player.playFromQueue(index: absoluteIndex)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                player.removeUpcoming(at: IndexSet(integer: index))
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .listRowInsets(.init(top: 5, leading: 8, bottom: 5, trailing: 8))
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    player.moveUpcoming(from: source, to: destination)
                }
            }
        } else if player.currentTrack != nil {
            Text("End of Queue")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing Playing",
            systemImage: "list.bullet.rectangle",
            description: Text("Start a song or queue tracks to manage what's next.")
        )
    }
}
