import SwiftUI

struct ArtistTabView: View {
    @State private var viewModel = ArtistCollectionViewModel()
    @State private var isGridView = true
    @State private var showingAddArtist = false
    @State private var newArtistName = ""

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
                .alert("Add Artist", isPresented: $showingAddArtist) {
                    TextField("Artist Name", text: $newArtistName)
                    Button("Cancel", role: .cancel) { newArtistName = "" }
                    Button("Add") {
                        addArtist()
                    }
                } message: {
                    Text("Enter the name of the artist you want to follow.")
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

    private func addArtist() {
        let nameToAdd = newArtistName.trimmingCharacters(in: .whitespacesAndNewlines)
        newArtistName = ""
        if !nameToAdd.isEmpty {
            Task {
                await viewModel.addArtist(name: nameToAdd)
            }
        }
    }
}

#Preview {
    ArtistTabView()
}
