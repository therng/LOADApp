import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: AudioPlayerService

    private var continueTracks: [Track] {
        player.continuePlaying.filter { $0.id != player.currentTrack?.id }
    }

    private var hasContent: Bool {
        player.currentTrack != nil || !player.userQueue.isEmpty || !continueTracks.isEmpty
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGray6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            if hasContent {
                queueList
            } else {
                emptyState
            }
        }
        .navigationTitle("Playing Next")
        .navigationBarTitleDisplayMode(.automatic)
        .foregroundColor(.primary)
        .background(backgroundGradient)
        .tint(.blue)
    }

    private var queueList: some View {
        List {
            Section("Queue") {
                if player.userQueue.isEmpty {
                    Text("No queued tracks")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(player.userQueue.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact()
                                player.play(track: track)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Haptics.impact(.medium)
                                    player.removeFromUserQueue(at: IndexSet(integer: index))
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .listRowInsets(.init(top: 5, leading: 8, bottom: 5, trailing: 8))
                            .listRowSeparator(.hidden)
                    }
                }
            }

            Section("Continue Playing") {
                if continueTracks.isEmpty {
                    Text("Nothing scheduled after this")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(continueTracks) { track in
                        TrackRow(track: track, isDimmed: true)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact()
                                player.enqueueNext(track)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Queue Next", systemImage: "text.insert") {
                                    Haptics.selection()
                                    player.enqueueNext(track)
                                }
                                .tint(.blue)
                            }
                            .listRowInsets(.init(top: 5, leading: 8, bottom: 5, trailing: 8))
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(8)
        .scrollContentBackground(.hidden)
        .toolbarTitleDisplayMode(.automatic)
        
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    player.shuffleUserQueue()
                } label: {
                    Image(systemName: "shuffle")
                }
                .disabled(player.userQueue.count < 2)

                Button(role: .destructive) {
                    Haptics.impact(.medium)
                    player.clearUserQueue()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(player.userQueue.isEmpty)
            }
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

