import SwiftUI
import UIKit

struct SearchTabView: View {
    @State private var searchModel = SearchViewModel()

    
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
                if let response = searchModel.presentedResponse {
                    HistoryDetailView(searchId: response.search_id, preloadedResponse: response)
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
        }
    }

}

#Preview {
    SearchTabView()
        .environment(AudioPlayerService.shared)
}
