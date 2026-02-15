import SwiftUI

struct ArtistEmptyStateView: View {
    @Binding var showingAddArtist: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.mic.circle")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .shadow(radius: 5)
            
            VStack(spacing: 8) {
                Text("No Followed Artists")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Follow artists from the player or search to see them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                showingAddArtist = true
            } label: {
                Text("Add Artist Manually")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }
}
