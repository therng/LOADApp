import Foundation

@MainActor
final class SearchHistoryService: ObservableObject {
    static let shared = SearchHistoryService()

    @Published private(set) var recentQueries: [String] = []

    private let storageKey = "recentSearches"
    private let maxQueries = 8

    private init() {
        load()
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentQueries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentQueries.insert(trimmed, at: 0)
        if recentQueries.count > maxQueries {
            recentQueries = Array(recentQueries.prefix(maxQueries))
        }
        save()
    }

    func remove(_ query: String) {
        recentQueries.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        save()
    }

    func clear() {
        recentQueries = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            recentQueries = try JSONDecoder().decode([String].self, from: data)
        } catch {
            recentQueries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(recentQueries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
