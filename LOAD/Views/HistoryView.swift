import SwiftUI

struct HistoryView: View {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    
    @Binding var selectedTab: Int
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    @EnvironmentObject var player: AudioPlayerService
    @State private var historyItems: [HistoryItem] = []
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var showClearConfirmation = false
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
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyItems.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All History", role: .destructive) {
                    clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .task {
                await loadHistory(force: true)
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
                    HStack {
                        Text(item.query)
                            .lineLimit(1)
                            .font(.body)
                        Spacer()
                        Text(Self.relativeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await addAllToQueue(item) }
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Retry", systemImage: "magnifyingglass.circle") {
                        retrySearch(item)
                    }
                    .tint(.accentColor)
                    
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Image(systemName: "trash")
                            .accessibilityLabel("Delete")
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

    private func retrySearch(_ item: HistoryItem) {
        Haptics.impact(.medium)
        // Update shared bindings
        searchText = item.query
        isSearchPresented = false // Closing the bar often triggers the search in onSubmit logic or onChange
        selectedTab = 0 // Switch to Search Tab
    }

    private func loadHistory(force: Bool = false) async {
        if isLoading { return }
        isLoading = true
        do {
            let items = try await APIService.shared.fetchHistory()
            historyItems = items
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isLoading = false
    }

    private func clearHistory() {
        Task {
            do {
                _ = try await APIService.shared.deleteAllHistory()
                historyItems = []
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func deleteItem(_ item: HistoryItem) {
        Task {
            do {
                _ = try await APIService.shared.deleteHistoryItem(id: item.search_id)
                historyItems.removeAll { $0.search_id == item.search_id }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func addAllToQueue(_ item: HistoryItem) async {
        do {
            let response = try await APIService.shared.fetchSearchResult(id: item.search_id)
            await MainActor.run {
                AudioPlayerService.shared.addHistory(from: response)
                for track in response.results {
                    AudioPlayerService.shared.addToQueue(track)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
