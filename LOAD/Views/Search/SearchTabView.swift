import SwiftUI
import UIKit

struct SearchTabView: View {
    @State private var searchModel = SearchViewModel()
    @Environment(AppNavigationManager.self) var navigationManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Base Content: History
                HistoryView { query in
                    searchModel.searchText = query
                    searchModel.performSearch()
                }
                
                // Loading Overlay
                if searchModel.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationDestination(isPresented: $searchModel.shouldNavigateToResult) {
                if searchModel.shouldNavigateToResult, let response = searchModel.presentedResponse {
                    HistoryDetailView(searchId: response.searchId, preloadedResponse: response)
                }
            }
            .searchable(
                text: $searchModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search"
            )
            .onSubmit(of: .search) {
                searchModel.performSearch()
            }
            .onChange(of: navigationManager.pendingSearchQuery) { _, newQuery in
                if let query = newQuery, !query.isEmpty {
                    searchModel.searchText = query
                    searchModel.performSearch()
                    navigationManager.pendingSearchQuery = nil
                }
            }
            .onAppear {
                if let query = navigationManager.pendingSearchQuery, !query.isEmpty {
                    searchModel.searchText = query
                    searchModel.performSearch()
                    navigationManager.pendingSearchQuery = nil
                }
            }
        }
    }

}

#Preview {
    SearchTabView()
        .environment(AudioPlayerService.shared)
}
