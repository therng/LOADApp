import SwiftUI

@MainActor
@Observable
class SearchViewModel {
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var presentedResponse: SearchResponse?
    var shouldNavigateToResult: Bool = false
    
    func performSearch() {
        // Dismiss keyboard manually since .searchable focus binding isn't available/reliable here
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        presentedResponse = nil
        shouldNavigateToResult = false
        
        Task {
            do {
                let (searchId, tracks) = try await APIService.shared.search(query: q)
                let response = SearchResponse(searchId: searchId, results: tracks, query: q, count: tracks.count)
                self.presentedResponse = response
                self.shouldNavigateToResult = true
                
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
