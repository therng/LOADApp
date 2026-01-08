import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: AudioPlayerService
    
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
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                if !player.queue.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            clearQueue()
                        }
                        .font(.body)
                    }
                }
            }
        }
    }
    
    // MARK: - Queue List
    
    private var queueList: some View {
        List {
            ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                QueueTrackRow(
                    track: track,
                    index: index + 1,
                    isCurrent: isCurrentTrack(track),
                    isPlaying: isCurrentTrack(track) && player.isPlaying
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    player.play(track: track)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeTrack(track)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowSeparator(index < player.queue.count - 1 ? .automatic : .hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(isCurrentTrack(track) ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .onMove { from, to in
                var updatedQueue = player.queue
                updatedQueue.move(fromOffsets: from, toOffset: to)
                
                // Update queueIndex if it exists
                if let currentIndex = player.queueIndex {
                    var newIndex = currentIndex
                    if from.contains(currentIndex) {
                        newIndex = to
                    } else if currentIndex > from.first! && currentIndex <= to {
                        newIndex -= 1
                    } else if currentIndex >= to && currentIndex < from.first! {
                        newIndex += 1
                    }
                    player.setQueue(updatedQueue, startAt: updatedQueue[safe: newIndex])
                } else {
                    player.setQueue(updatedQueue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Tracks in Queue",
            systemImage: "list.bullet",
            description: Text("Play a track to start your queue")
        )
    }
    
    // MARK: - Helpers
    
    private func isCurrentTrack(_ track: Track) -> Bool {
        player.currentTrack?.id == track.id
    }
    
    private func removeTrack(_ track: Track) {
        var updatedQueue = player.queue
        guard let index = updatedQueue.firstIndex(where: { $0.id == track.id }) else { return }
        updatedQueue.remove(at: index)
        
        // Update queueIndex if needed
        if let currentIndex = player.queueIndex {
            if index == currentIndex {
                // Removing current track - try to play next or clear
                if updatedQueue.isEmpty {
                    player.stop()
                    player.setQueue([])
                } else if currentIndex < updatedQueue.count {
                    player.setQueue(updatedQueue, startAt: updatedQueue[currentIndex])
                    player.play(track: updatedQueue[currentIndex])
                } else if currentIndex > 0 {
                    let newIndex = currentIndex - 1
                    player.setQueue(updatedQueue, startAt: updatedQueue[newIndex])
                    player.play(track: updatedQueue[newIndex])
                } else {
                    player.setQueue(updatedQueue)
                }
            } else if index < currentIndex {
                // Track before current was removed, adjust index
                player.setQueue(updatedQueue, startAt: player.currentTrack)
            } else {
                // Track after current was removed, no index change needed
                player.setQueue(updatedQueue, startAt: player.currentTrack)
            }
        } else {
            player.setQueue(updatedQueue)
        }
    }
    
    private func clearQueue() {
        // Only clear queue, don't stop current playback
        player.setQueue([])
    }
}

// MARK: - Queue Track Row

private struct QueueTrackRow: View {
    let track: Track
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Queue position indicator
            ZStack {
                if isCurrent {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 24, height: 24)
                    
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 24)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(isCurrent ? .semibold : .medium)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .primary : .primary)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.durationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
