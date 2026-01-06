import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var isHistoryPresented = false
    
    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    emptyView
                } else {
                    queueList
                }
            }
            .navigationTitle("Up Next")
            .toolbar {
                Button("History", systemImage: "clock.arrow.circlepath") {
                    isHistoryPresented = true
                }
            }
            .sheet(isPresented: $isHistoryPresented) {
                HistoryView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var queueList: some View {
        List {
            ForEach(player.queue) { track in
                TrackRow(track: track)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.play(track: track)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            .onMove { from, to in
                var updatedQueue = player.queue
                updatedQueue.move(fromOffsets: from, toOffset: to)
                player.setQueue(updatedQueue)
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Tracks in Queue",
            systemImage: "list.bullet",
            description: Text("Play a track to start your queue")
        )
    }
}
