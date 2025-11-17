import SwiftUI
import SafariServices

struct TrackRow: View {
    let track: Track
    @State private var showSafari = false
    @EnvironmentObject private var vm: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {

            HStack(alignment: .center, spacing: 14) {

                // Title + Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration Right-Aligned
                Text(track.formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
                    .monospacedDigit()
                    .lineLimit(1)
            }
          
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                vm.play(track)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    showSafari = true
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .tint(Color.accentColor.opacity(0.35))
            }
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: track.download)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    TrackRow(track: .sample)
        .environmentObject(HomeViewModel.makeDefault())
}
