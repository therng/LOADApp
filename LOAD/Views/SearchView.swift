import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: AudioPlayerService
    
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedSearchId: String?
    @FocusState var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if !searchText.isEmpty {
                    emptyView
                }
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: Text(searchText.isEmpty ? "Search" : searchText)
            )
            .onSubmit(of: .search) {
                isSearchFocused = false
                performSearch()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { presentedSearchId != nil },
                    set: { if !$0 { presentedSearchId = nil } }
                )
            ) {
                if let searchId = presentedSearchId {
                    HistoryDetailView(searchId: searchId)
                }
            }
            .onChange(of: isSearchPresented) { _, presented in
                isSearchFocused = presented
            }
            // Trigger search if searchText is updated from outside (e.g. HistoryView)
            .onChange(of: searchText) { _, newValue in
                if !isSearchPresented && !newValue.isEmpty {
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        isSearchPresented = false
        
        Task {
            do {
                let response = try await APIService.shared.search(query: q)
                player.addHistory(from: response)
                self.presentedSearchId = response.search_id
                Haptics.impact(.medium)
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tracks found")
                .font(.headline)
            Text("Try a different search")
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}
