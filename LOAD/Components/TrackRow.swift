import SwiftUI

struct TrackRow: View {
    let track: Track
    var isDimmed: Bool = false
    
    // Feature Configuration
    var showSaveAction: Bool = false
    
    // Interaction closures
    var onPlay: (() -> Void)?
    var onCopy: (() -> Void)?
    
    @State private var showSavedBanner = false
    @Environment(AudioPlayerService.self) var player
    
    private var isCurrent: Bool {
        player.currentTrack?.id == track.id
    }

    private var isPlaying: Bool {
        isCurrent && player.isPlaying
    }
    
    private var nonCurrentPrimary: Color {
        isDimmed ? .secondary : .primary
    }

    private var nonCurrentSecondary: Color {
        isDimmed ? .secondary.opacity(0.6) : .secondary
    }
    
    private var currentProgress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isCurrent {
                    CircularProgressView(
                        progress: currentProgress,
                        isPlaying: isPlaying,
                        animationDuration: .linear
                    )
                }
            }
            // MARK: - Track Info
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .accentColor : nonCurrentPrimary)
                Text(track.artist)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? .accentColor : nonCurrentSecondary)
            }
            
            Spacer()
            
            Text(track.durationText)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(isCurrent ? .accentColor : nonCurrentSecondary)
        }
        .overlay(alignment: .bottom) {
            if showSavedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                    Text("Track Saved")
                }
                .font(.subheadline.weight(.semibold))
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(radius: 5)
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .interactiveItem(onTap: onPlay, onLongPress: onCopy)
        .contextMenu {
            TrackActionMenuItems(
                track: track,
                showSaveButton: showSaveAction,
                onSaveSuccess: {
                    withAnimation {
                        showSavedBanner = true
                    }
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation {
                            showSavedBanner = false
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Interactive Item Modifier

struct InteractiveItemModifier: ViewModifier {
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.5, perform: {
                if let onLongPress {
                    Haptics.impact(.medium)
                    onLongPress()
                }
            }, onPressingChanged: { pressing in
                isPressed = pressing
            })
            .onTapGesture {
                if let onTap {
                    onTap()
                }
            }
    }
}

extension View {
    func interactiveItem(onTap: (() -> Void)? = nil, onLongPress: (() -> Void)? = nil) -> some View {
        modifier(InteractiveItemModifier(onTap: onTap, onLongPress: onLongPress))
    }
}
