import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
// Defining SafariURLItem here makes it accessible to other Views
struct SafariURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

