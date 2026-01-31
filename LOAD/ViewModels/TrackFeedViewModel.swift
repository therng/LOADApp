import Foundation
import Combine
import SwiftUI

@MainActor
class TrackFeedViewModel: ObservableObject {
    @Published var tracks: [iTunesSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storageService = ArtistStorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        storageService.$artists
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] artists in
                self?.fetchLatestTracks(for: artists)
            }
            .store(in: &cancellables)
    }
    
    func fetchLatestTracks(for artists: [Artist]? = nil) {
        let artistsToFetch = artists ?? storageService.artists
        guard !artistsToFetch.isEmpty else {
            self.tracks = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let artistIds = artistsToFetch.map { $0.artistId }
            do {
                let results = try await APIService.shared.fetchTracksForArtists(artistIds: artistIds)
                self.tracks = results
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
