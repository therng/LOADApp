import Foundation

@MainActor
final class TrackSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tracks = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let results = try await APIService.shared.searchTracks(query: trimmed)
            tracks = results
            if results.isEmpty {
                errorMessage = "No tracks found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clear() {
        query = ""
        tracks = []
        errorMessage = nil
    }
}
