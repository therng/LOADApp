import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    let onSave: (URL) -> Void
    let player: AudioPlayerService

    var body: some View {
        Button("Play Next", systemImage: "text.insert") {
            Haptics.impact()
            player.enqueueNext(track)
        }

        Button("Add to Queue", systemImage: "text.badge.plus") {
            Haptics.selection()
            player.addToQueue(track)
        }

        ShareLink(
            item: track.download,
            subject: Text(track.title),
            message: Text("\(track.artist) - \(track.title)")
        ) {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button("Save", systemImage: "arrow.down.circle") {
            Haptics.impact(.medium)
            onSave(track.download)
        }
    }
}
