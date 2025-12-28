import SwiftUI

struct HistoryView: View {
    @State private var historyItems: [HistoryItem] = []
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
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
            .navigationBarTitleDisplayMode(.automatic)
            .navigationTransition(.automatic)
            .assistiveAccessNavigationIcon(systemImage: "history")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !historyItems.isEmpty {
                        Button("Clear", systemImage: "trash") {
                            clearHistory()
                        }
                        .tint(.red)
                    }
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
                        
                        Text(Self.relativeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
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
        .listStyle(.plain)
        .refreshable {
            await loadHistory(force: true)
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Your search history will appear here")
        } actions: {
            Button("Reload") {
                Task { await loadHistory(force: true) }
            }
        }
    }
    
    private func loadHistory(force: Bool = false) async {
        let shouldLoad = await MainActor.run { () -> Bool in
            if isLoading { return false }
            if !force && !historyItems.isEmpty { return false }
            isLoading = true
            errorMessage = nil
            showErrorAlert = false
            return true
        }
        
        guard shouldLoad else { return }
        
        do {
            let items = try await APIService.shared.fetchHistory()
            await MainActor.run {
                withAnimation {
                    historyItems = items
                }
                isLoading = false
            }
        } catch {
            if isCancellation(error) {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isLoading = false
            }
        }
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
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
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
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIService.APIError {
            switch apiError {
            case .cancelled:
                return true
            case .network(let underlying):
                if let urlError = underlying as? URLError, urlError.code == .cancelled {
                    return true
                }
                let nsError = underlying as NSError
                return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
            default:
                return false
            }
        }
        return false
    }
}
