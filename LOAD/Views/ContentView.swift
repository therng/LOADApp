import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = TrackSearchViewModel()
    @State private var safariLink: SafariLink?

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

                if let message = viewModel.errorMessage, !viewModel.isLoading {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                ForEach(viewModel.tracks) { track in
                    TrackRow(track: track)
                        .contextMenu {
                            ShareLink(item: track.stream) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                UIPasteboard.general.string = "\(track.artist) — \(track.title)"
                            } label: {
                                Label("Copy text", systemImage: "doc.on.doc")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                safariLink = SafariLink(url: track.download)
                            } label: {
                                Label("Save", systemImage: "safari")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .safeAreaInset(edge: .bottom) {
                searchBar
            }
            .sheet(item: $safariLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
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
                TextField("Search tracks", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel("Clear search")
            }

            Button {
                Task {
                    await viewModel.search()
                }
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 28))
            }
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
        .overlay(
            Divider(),
            alignment: .top
        )
    }
}

#Preview {
    ContentView()
}
