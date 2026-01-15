import SwiftUI

struct TrackActionMenuItems: View {
    let track: Track
    let onSave: (URL) -> Void
    let onGoToArtist: (String) -> Void
    let player: AudioPlayerService

    private var shareableText: String { "\(track.artist) - \(track.title)" }
   

    var body: some View {
        Button("Play Next", systemImage: "text.insert") {
            Haptics.impact()
            player.enqueueNext(track)
        }

        Button("Add to Queue", systemImage: "text.badge.plus") {
            Haptics.selection()
            player.addToQueue(track)
        }
        
        Divider()

        Button("Go to Artist", systemImage: "music.mic") {
            Haptics.impact()
            onGoToArtist(track.artist)
        }

        Button("Copy Name", systemImage: "doc.on.doc") {
            Haptics.selection()
            let textToCopy = shareableText
            #if canImport(UIKit)
            UIPasteboard.general.string = textToCopy
            #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
            #endif
        }
        
        ShareLink(
            item: track.download,
            subject: Text(track.title),
            message: Text(shareableText)
        ) {
            Label("Share Track", systemImage: "square.and.arrow.up")
        }
        
        Divider()

        Button("Save to Files", systemImage: "arrow.down.circle") {
            Haptics.impact(.medium)
            onSave(track.download)
        }
    }
}

