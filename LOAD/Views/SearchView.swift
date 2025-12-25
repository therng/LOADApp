import SafariServices
import SwiftUI
import UIKit

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var safariDestination: SafariDestination?
    @Published var sharePayload: SharePayload?

    func submitSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await APIService.shared.searchTracks(query: trimmed)
                tracks = results
            } catch {
                errorMessage = error.localizedDescription
                tracks = []
            }
            isLoading = false
        }
    }

    func clearResults() {
        tracks = []
        errorMessage = nil
        isLoading = false
    }

    func openInSafari(track: Track) {
        safariDestination = SafariDestination(url: track.download)
    }

    func share(track: Track) {
        let shareText = "\(track.title) — \(track.artist)"
        sharePayload = SharePayload(items: [shareText, track.download])
    }

    func copy(track: Track) {
        UIPasteboard.general.string = "\(track.title) — \(track.artist)"
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Searching…")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text(errorMessage)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                }

                ForEach(viewModel.tracks) { track in
                    TrackRow(track: track)
                        .contextMenu {
                            Button {
                                viewModel.share(track: track)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }

                            Button {
                                viewModel.copy(track: track)
                            } label: {
                                Label("Copy Text", systemImage: "doc.on.doc")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                viewModel.openInSafari(track: track)
                            } label: {
                                Label("Save", systemImage: "safari")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Track Search")
            .overlay {
                if viewModel.tracks.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                    ContentUnavailableView(
                        "Search for music",
                        systemImage: "magnifyingglass",
                        description: Text("Enter a query and submit to load matching tracks.")
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                SearchBar(
                    query: $query,
                    isFocused: $isSearchFocused,
                    onSubmit: {
                        viewModel.submitSearch(query: query)
                    },
                    onClear: {
                        query = ""
                        viewModel.clearResults()
                    }
                )
            }
        }
        .sheet(item: $viewModel.safariDestination) { destination in
            SafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .sheet(item: $viewModel.sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(track.title)
                .font(.headline)
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

struct SearchBar: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search term", text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            if !query.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct SafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    SearchView()
}
