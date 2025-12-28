import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var historyItems: [HistoryItem] = []
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if historyItems.isEmpty {
                    emptyView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !historyItems.isEmpty {
                    Button("Clear", systemImage: "trash") {
                        clearHistory()
                    }
                    .tint(.red)
                }
            }
            .task {
                await loadHistory()
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }
    
    private var historyList: some View {
        List {
            ForEach(historyItems, id: \.search_id) { item in
                NavigationLink {
                    HistoryDetailView(searchId: item.search_id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.query)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(item.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteItem(item)
                    }
                }
            }
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No History",
            systemImage: "clock.arrow.circlepath",
            description: Text("Your search history will appear here")
        )
    }
    
    private func loadHistory() async {
        await MainActor.run { isLoading = true }
        do {
            let items = try await APIService.shared.fetchHistory()
            await MainActor.run {
                self.historyItems = items
            }
            print("[HistoryView] Loaded \(items.count) history items.")
        } catch {
            print("[HistoryView] Error loading history: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
        await MainActor.run { isLoading = false }
    }
    
    private func clearHistory() {
        Task {
            do {
                print("[HistoryView] Clearing all history…")
                _ = try await APIService.shared.deleteAllHistory()
                await MainActor.run {
                    withAnimation {
                        historyItems = []
                    }
                }
                print("[HistoryView] Cleared all history.")
            } catch {
                print("[HistoryView] Error clearing history: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func deleteItem(_ item: HistoryItem) {
        Task {
            do {
                print("[HistoryView] Deleting item id=\(item.search_id)")
                _ = try await APIService.shared.deleteHistoryItem(id: item.search_id)
                await MainActor.run {
                    withAnimation {
                        historyItems.removeAll { $0.search_id == item.search_id }
                    }
                }
                print("[HistoryView] Deleted item id=\(item.search_id)")
            } catch {
                print("[HistoryView] Error deleting item id=\(item.search_id): \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}
