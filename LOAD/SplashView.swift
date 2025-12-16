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

    // Transition to main app (TabView)
    private var appTransition: AnyTransition {
        AnyTransition.asymmetric(
            insertion:
                .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98)),
            removal:
                .opacity
                .combined(with: .scale(scale: 0.95))
        )
    }

    var body: some View {
        Group {
            if isActive {
                SearchView()
                    .transition(appTransition)
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
                            runLogoAnimation()
                        }
                }
                .task {
                    await runStartupTasks()
                }
            }
        }
    }

    // MARK: - Animations

    private func runLogoAnimation() {
        // Phase 1: Fade-in + slight zoom + rotate
        withAnimation(.easeOut(duration: 0.55)) {
            opacity = 1.0
            scale = 1.08
            rotation = -2.5
        }

        // Phase 2: Spring back
        withAnimation(
            .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.15)
                .delay(0.5)
        ) {
            scale = 1.0
            rotation = 0.0
        }
    }

    // MARK: - Startup Tasks

    private func runStartupTasks() async {
        // Minimum splash display time
        async let minDisplay: Void = {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }()

        // Warm up backend (non-blocking UX)
        async let warmUp: Void = APIService.shared.warmUp()

        _ = await (minDisplay, warmUp)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            isActive = true
        }
    }
}

#Preview {
    SplashView()
}
