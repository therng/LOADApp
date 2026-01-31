import SwiftUI
import Combine

enum SearchMode {
    case library
    case artist
}

@MainActor
class SearchModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var presentedResponse: SearchResponse?
    @Published var searchMode: SearchMode = .library
    @Published var shouldNavigateToResult: Bool = false
    
    // For artist search results
    @Published var artistAlbums: [iTunesSearchResult] = []
    
    func performSearch() {
        // Dismiss keyboard manually since .searchable focus binding isn't available/reliable here
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        presentedResponse = nil
        artistAlbums = []
        shouldNavigateToResult = false
        
        Task {
            do {
                switch searchMode {
                case .library:
                    let (searchId, tracks) = try await APIService.shared.search(query: q)
                    let response = SearchResponse(search_id: searchId, results: tracks, query: q, count: tracks.count)
                    self.presentedResponse = response
                    self.shouldNavigateToResult = true
                    
                case .artist:
                    let albums = try await APIService.shared.searchForArtistAlbums(q)
                    self.artistAlbums = albums
                }
                
                Haptics.impact(.medium)
                self.isLoading = false
            } catch {
                // Ignore cancellation errors
                if let apiError = error as? APIService.APIError, case .cancelled = apiError {
                    return
                }
                
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
