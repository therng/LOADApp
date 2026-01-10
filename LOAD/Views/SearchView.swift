import SwiftUI

private struct SuffixSuggestion: Identifiable, Hashable {
    let id: String
    let display: String
    let completion: String
}

struct SearchView: View {
    @EnvironmentObject var player: AudioPlayerService

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState var isSearchFocused: Bool
    @State private var isSearchPresented = true
    @State private var safariURL: URL?
    @State private var safariDetent: PresentationDetent = .medium
    @State private var presentedSearchId: String?
    private let listSpacing: CGFloat = 12
//    private let suffixSuggestions: [SuffixSuggestion] = [
//        .init(id: "extended", display: "Extended", completion: "(Extended Mix)"),
//        .init(id: "remix", display: "Remix", completion: "(Extended Remix)"),
//        .init(id: "bootleg", display: "Bootleg", completion: "Bootleg")
//    ]

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

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
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .searchToolbarBehavior(.minimize)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: Text("Search")
            )
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Extended") {
                        appendCompletion("(Extended Mix)")
                    }
                    Button("Remix") {
                        appendCompletion("(Extended Remix)")
                    }
                    Button("Bootleg") {
                        appendCompletion("Bootleg")
                    }
                }
            }
            .onSubmit(of: .search) {
                isSearchFocused = false
                isSearchPresented = false
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
            .sheet(
                isPresented: Binding(
                    get: { safariURL != nil },
                    set: { if !$0 { safariURL = nil } }
                )
            ) {
                if let safariURL {
                    SafariView(url: safariURL)
                        .presentationDetents([.medium, .large], selection: $safariDetent)
                        .presentationDragIndicator(.visible)
                }
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

    private func applySuggestion(_ suggestion: SuffixSuggestion) {
        guard hasQuery else { return }
        var next = trimmedQuery
        if !next.localizedCaseInsensitiveContains(suggestion.completion) {
            next += " \(suggestion.completion)"
        }
        searchText = next
        isSearchPresented = true
        Haptics.selection()
    }

    private func appendCompletion(_ completion: String) {
        let base = trimmedQuery
        var next = base
        if base.isEmpty {
            next = completion
        } else if !base.localizedCaseInsensitiveContains(completion) {
            next = base + " " + completion
        }
        searchText = next
        isSearchPresented = true
        Haptics.selection()
    }

    private func performSearch() {
        let q = trimmedQuery
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        isSearchPresented = false
        isSearchFocused = false
        Task {
            do {
                let response = try await APIService.shared.search(query: q)
                player.addHistory(from: response)
                presentedSearchId = response.search_id
                Haptics.impact(.medium)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
