import SwiftUI
import Combine

struct HistoryView: View {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    
    let onSelect: (String) -> Void
    @Environment(AudioPlayerService.self) var player
    @State private var historyItems: [HistoryItem] = []
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var showClearConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
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

    private var historyList: some View {
        List {
            ForEach(historyItems) { item in
                NavigationLink {
                    HistoryDetailView(searchId: item.searchId)
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
                        retrySearch(item)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .tint(Color.accentColor)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .background(.clear)
            }
        }
        .listStyle(.plain)
   
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
        onSelect(item.query)
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
                _ = try await APIService.shared.deleteAllHistoryItems()
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
                _ = try await APIService.shared.deleteHistoryItem(with: item.searchId)
                historyItems.removeAll { $0.searchId == item.searchId }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
