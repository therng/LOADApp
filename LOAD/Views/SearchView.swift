import SwiftUI
import UIKit

struct SearchView: View {
    @State private var query = ""
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchBar

                if isLoading {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                trackResults
            }
            .padding()
            .navigationTitle("Search")
            .task {
                await APIService.shared.warmUp()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search tracks", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )

            Button {
                query = ""
                tracks = []
                errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear search")

            Button("Search") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    private var trackResults: some View {
        Group {
            if tracks.isEmpty {
                Text("Search for a track to get started.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    ForEach(tracks) { track in
                        TrackRow(track: track)
                            .contextMenu {
                                ShareLink(item: track.download) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    UIPasteboard.general.string = track.shareText
                                } label: {
                                    Label("Copy text", systemImage: "doc.on.doc")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    openURL(track.download)
                                } label: {
                                    Label("Save", systemImage: "safari")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                tracks = try await APIService.shared.searchTracks(query: trimmed)
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

private struct TrackRow: View {
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
        .padding(.vertical, 6)
    }
}

private extension Track {
    var shareText: String {
        "\(title) — \(artist)"
    }
}

#Preview {
    SearchView()
}
