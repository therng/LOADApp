import SwiftUI
import SafariServices

@available(iOS 18.0, *)
struct TrackRow: View {
    let track: Track
    @State private var showSafari = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Artwork placeholder (เล็ก ๆ สำหรับ list/row)
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "music.note").font(.subheadline).foregroundStyle(.white.opacity(0.85)))

            // Left: Title + Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right: Duration ชิดขวาสุด
            Text(track.duration.isEmpty ? "0:00" : track.duration)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showSafari = true
            } label: {
                Label("Open", systemImage: "safari")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: track.stream)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    TrackRow(
        track: Track(
            id: 1,
            artist: "Armin van Buuren",
            title: "In And Out Of Love",
            duration: "3:00",
            download: URL(string: "https://example.com")!,
            stream: URL(string: "https://example.com")!
        )
    )
}
