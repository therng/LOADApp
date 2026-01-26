import SwiftUI

struct HistoryView: View {
    var onSelectQuery: (String) -> Void
    
    @State private var historyItems: [HistoryItem] = []
    @State private var isLoading = false
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    
    var body: some View {
        List {
            if !historyItems.isEmpty {
                Section {
                    ForEach(historyItems, id: \.search_id) { item in
                        Button {
                            onSelectQuery(item.query)
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(item.query)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(Self.relativeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear") {
                            clearHistory()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            } else if !isLoading {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Your search history will appear here."))
            }
        }
        .listStyle(.insetGrouped)
        .onAppear {
            Task { await loadHistory() }
        }
    }
    
    private func loadHistory() async {
        isLoading = true
        do {
            historyItems = try await APIService.shared.fetchHistory()
        } catch {
            print("Failed to load history: \(error)")
        }
        isLoading = false
    }
    
    private func deleteItem(_ item: HistoryItem) {
        Task {
            _ = try? await APIService.shared.deleteHistoryItem(with: item.search_id)
            await loadHistory()
        }
    }
    
    private func clearHistory() {
        Task {
            _ = try? await APIService.shared.deleteAllHistoryItems()
            historyItems = []
        }
    }
}
