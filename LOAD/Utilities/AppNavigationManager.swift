import SwiftUI

@MainActor
@Observable
class AppNavigationManager {
    var selectedTab: Int = 0
    var pendingSearchQuery: String? = nil
    
    func triggerSearch(query: String) {
        self.selectedTab = 0 // Search Tab
        self.pendingSearchQuery = query
    }
}
