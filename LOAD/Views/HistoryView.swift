import SwiftUI

struct HistoryView: View {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
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
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyItems.isEmpty {
                        Button("Clear", role: .destructive) {
                            clearHistory()
                        }
                    }
                }
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
                .contextMenu {
                    Button("Retry Search", systemImage: "magnifyingglass.circle") {
                        Task { await retrySearch(item) }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await addAllToQueue(item) }
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .accessibilityLabel("Add All")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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

    // MARK: - Actions

    private func loadHistory(force: Bool = false) async {
        if isLoading { return }
        if !force && !historyItems.isEmpty { return }

        isLoading = true
        errorMessage = nil
        showErrorAlert = false

        do {
            let items = try await APIService.shared.fetchHistory()
            historyItems = items
            isLoading = false
        } catch {
            if isCancellation(error) {
                isLoading = false
                return
            }
            errorMessage = error.localizedDescription
            showErrorAlert = true
            isLoading = false
        }
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

    private func retrySearch(_ item: HistoryItem) async {
        do {
            let response = try await APIService.shared.fetchSearchResult(id: item.search_id)
            await MainActor.run {
                Haptics.impact(.medium)
                AudioPlayerService.shared.addHistory(from: response)
                historyItems.removeAll { $0.search_id == item.search_id }
                historyItems.insert(item, at: 0)
                AudioPlayerService.shared.setQueue(response.results, startAt: response.results.first)
                if let first = response.results.first {
                    AudioPlayerService.shared.play(track: first)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func addAllToQueue(_ item: HistoryItem) async {
        do {
            let response = try await APIService.shared.fetchSearchResult(id: item.search_id)
            await MainActor.run {
                Haptics.selection()
                AudioPlayerService.shared.addHistory(from: response)
                for track in response.results {
                    AudioPlayerService.shared.addToQueue(track)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
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
