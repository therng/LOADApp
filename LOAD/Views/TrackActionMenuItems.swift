import SwiftUI
import UIKit

struct TrackActionMenuItems: View {
    let track: Track
    let onSave: (URL) -> Void

    var body: some View {
        Button("Add to Favourite", systemImage: "heart") {
            FavoritesStore.shared.add(track)
        }

        Button("Copy Text", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = "\(track.artist) - \(track.title)"
        }

        Button("Save", systemImage: "arrow.down.circle") {
            onSave(track.download)
        }

        ShareLink(
            item: track.download,
            subject: Text(track.title),
            message: Text("\(track.artist) - \(track.title)")
        ) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}
