import SwiftUI

struct ArtistTabView: View {
    @State private var viewModel = ArtistCollectionViewModel()
    @State private var isGridView = true
    @State private var showingAddArtist = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 15)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Artists")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isGridView.toggle() }
                        } label: {
                            Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        }
                        .accessibilityLabel(isGridView ? "Show as list" : "Show as grid")
                        
                        Button {
                            showingAddArtist = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add artist")
                    }
                }
                .sheet(isPresented: $showingAddArtist) {
                    ArtistSearchView { artistName in
                        Task {
                            await viewModel.addArtist(name: artistName)
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.artists.isEmpty {
            ArtistEmptyStateView(showingAddArtist: $showingAddArtist)
           
        } else if isGridView {
            ArtistGridView(viewModel: viewModel, columns: columns)
          
        } else {
            ArtistListView(viewModel: viewModel)

        }
    }
}

private struct ArtistSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [iTunesSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoading = false
    @State private var artistToConfirm: iTunesSearchResult?
    let onAddArtist: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && searchResults.isEmpty {
                    ProgressView()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView("No results for \"\(searchText)\"", systemImage: "magnifyingglass")
                } else {
                    List(searchResults) { result in
                        Button(action: {
                            artistToConfirm = result
                        }) {
                            HStack {
                                if let artworkURL = result.artworkURL {
                                    AsyncImage(url: artworkURL) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Image(systemName: "person.fill").font(.largeTitle)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                }
                                Text(result.artistName)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search for an artist")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    isLoading = true
                    defer { isLoading = false }
                    
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }

                    if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        do {
                            let results = try await APIService.shared.searchForArtists(newValue, limit: 5)
                            self.searchResults = results
                        } catch {
                            self.searchResults = []
                        }
                    } else {
                        self.searchResults = []
                    }
                }
            }
            .navigationTitle("Add Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Add Artist",
                isPresented: .constant(artistToConfirm != nil),
                presenting: artistToConfirm
            ) { artist in
                Button("Add \(artist.artistName)") {
                    onAddArtist(artist.artistName)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    artistToConfirm = nil
                }
            }
        }
    }
}

#Preview {
    ArtistTabView()
}
