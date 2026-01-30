import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var presentedResponse: SearchResponse?
    
    func performSearch() {
        // Dismiss keyboard manually since .searchable focus binding isn't available/reliable here
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        presentedResponse = nil // Reset to ensure navigation triggers fresh
        
        Task {
            do {
                let (searchId, tracks) = try await APIService.shared.search(query: q)
                let response = SearchResponse(search_id: searchId, results: tracks, query: q, count: tracks.count)
                
                self.presentedResponse = response
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
