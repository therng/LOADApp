import SwiftUI

struct TrackRow: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(track.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(track.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(track.durationText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
