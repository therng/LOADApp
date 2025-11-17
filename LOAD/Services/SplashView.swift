import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var isActive = false
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.8
    @State private var rotation: Double = 0.0

    private var splashAssetName: String {
        colorScheme == .dark ? "LogoW" : "LogoB"
    }

    // Define a richer transition for HomeView
    private var homeTransition: AnyTransition {
        // Enter: slide up + fade in + gentle scale up
        let insertion = AnyTransition.asymmetric(
            insertion:
                .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .center)),
            removal:
                .opacity
                .combined(with: .scale(scale: 0.95, anchor: .center))
        )
        return insertion
    }

    var body: some View {
        Group {
            if isActive {
                HomeView()
                    .environmentObject(HomeViewModel.makeDefault())
                    .transition(homeTransition)
            } else {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    Image(splashAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 180)
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            // Phase 1: Fade-in + slight zoom-in
                            withAnimation(.easeOut(duration: 0.55)) {
                                opacity = 1.0
                                scale = 1.08
                                rotation = -2.5
                            }
                            // Phase 2: Spring bounce back to 1.0 and reset rotation
                            withAnimation(
                                .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.15)
                                    .delay(0.5)
                            ) {
                                scale = 1.0
                                rotation = 0.0
                            }
                        }
                }
                .task {
                    // Display splash while warming API
                    async let minDisplay: Void = { try? await Task.sleep(nanoseconds: 3_000_000_000) }()
                    async let warm: Void = APIService.shared.warmUp()
                    _ = await (minDisplay, warm)

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
