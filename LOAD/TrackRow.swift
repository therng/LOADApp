import SwiftUI

struct TrackRow: View {
    @EnvironmentObject private var vm: HomeViewModel
    @Environment(\.openURL) private var openURL
    let track: Track

    private var isCurrent: Bool {
        vm.nowPlaying?.id == track.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Show play/pause button only on the current (now playing) track
            if isCurrent {
                Button {
                    HapticManager.shared.selection()
                    vm.isPlaying ? vm.pause() : vm.play(track)
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }
                .padding(2) // total footprint ~34x34
            } else {
                // Placeholder to keep titles aligned across rows
                Color.clear
                    .frame(width: 5, height: 34) // match button footprint
            }

            // Title and artist
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .foregroundColor(AppColors.textPrimary)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(track.durationText)
                .foregroundColor(AppColors.textSecondary)
                .font(.system(size: 14))
                .monospacedDigit()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.selection()
            if isCurrent {
                vm.isPlaying ? vm.pause() : vm.play(track)
            } else {
                vm.play(track)
            }
        }
        // Swipe left to open the download URL in Safari (Safari download manager)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                HapticManager.shared.selection()
                openURL(track.download)
            } label: {
                Label("Download", systemImage: "square.and.arrow.down")
            }
            .tint(AppColors.accent)
        }
    }
}

#Preview {
    TrackRow(track: Track(id: 1,
                          artist: "Artist",
                          title: "Title",
                          duration: 213,
                          download: URL(string: "https://example.com/dl")!,
                          stream: URL(string: "https://example.com/stream.m4a")!))
        .environmentObject(HomeViewModel.makeDefault())
}
