import Foundation
import SwiftUI

@MainActor
@Observable
class TrackFeedViewModel {
    var tracks: [iTunesSearchResult] = []
    var isLoading = false
    var errorMessage: String?
    
    var sortOption: TrackSortOption = .date
    var isAscending: Bool = false
    
    private let storageService = ArtistStorageService.shared
    
    var artists: [Artist] {
        storageService.artists
    }
    
    var sortedTracks: [iTunesSearchResult] {
        switch sortOption {
        case .date:
            return tracks.sorted(by: { lhs, rhs in
                return isAscending ? (lhs.releaseDate ?? .distantPast) < (rhs.releaseDate ?? .distantPast) : (lhs.releaseDate ?? .distantPast) > (rhs.releaseDate ?? .distantPast)
            })
        case .title:
            return tracks.sorted(by: { lhs, rhs in
                let t1 = lhs.trackName ?? ""
                let t2 = rhs.trackName ?? ""
                let result = t1.localizedCaseInsensitiveCompare(t2)
                return isAscending ? result == .orderedAscending : result == .orderedDescending
            })
        case .artist:
            return tracks.sorted(by: { lhs, rhs in
                let a1 = lhs.artistName
                let a2 = rhs.artistName
                let result = a1.localizedCaseInsensitiveCompare(a2)
                return isAscending ? result == .orderedAscending : result == .orderedDescending
            })
        case .duration:
            return tracks.sorted(by: {
                let d1 = $0.trackTimeMillis ?? 0
                let d2 = $1.trackTimeMillis ?? 0
                return isAscending ? d1 < d2 : d1 > d2
            })
        }
    }
    
    func fetchLatestTracks() {
        let artistsToFetch = self.artists
        guard !artistsToFetch.isEmpty else {
            self.tracks = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // Using compactMap safely handles optional artistId values
            // and results in a non-optional [Int] array.
            let artistIds = artistsToFetch.compactMap { $0.artistId }
            do {
                // The cast is no longer needed because artistIds is already [Int].
                let results = try await APIService.shared.fetchTracksForArtists(artistIds: artistIds)
                self.tracks = results
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

enum TrackSortOption: String, CaseIterable, Identifiable {
    case date, title, artist, duration

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .date: return "calendar"
        case .title: return "music.note"
        case .artist: return "person.fill"
        case .duration: return "clock"
        }
    }
    
    func displayName(isActive: Bool, isAscending: Bool) -> String {
        let name = rawValue.capitalized
        if !isActive { return name }
        return name + (isAscending ? " ↑" : " ↓")
    }
}
