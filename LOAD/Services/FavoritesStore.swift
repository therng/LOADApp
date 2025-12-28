import Combine
import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var favorites: [Track] = []

    private let storageKey = "favorites.tracks"

    private init() {
        load()
    }

    func add(_ track: Track) {
        guard !favorites.contains(where: { $0.id == track.id }) else { return }
        favorites.append(track)
        save()
    }

    func remove(_ track: Track) {
        favorites.removeAll { $0.id == track.id }
        save()
    }

    func contains(_ track: Track) -> Bool {
        favorites.contains(where: { $0.id == track.id })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            favorites = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            favorites = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
