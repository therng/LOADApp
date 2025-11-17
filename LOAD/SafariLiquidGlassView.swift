
import SwiftUI
import SafariServices

struct SafariLiquidGlassView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var glassOpacity: CGFloat = 1.0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            SafariView(url: url)
                .edgesIgnoringSafeArea(.all)

            // MARK: - Liquid Glass Header
            VStack {
                // Replace missing VisualEffectBlur with SwiftUI Material
                Rectangle()
                    .fill(.ultraThinMaterial)   // auto follow system
                    .frame(height: 58)
                    .overlay(alignment: Alignment.center) {
                        Capsule()
                            .fill(.thinMaterial)  // dynamic material (light/dark auto)
                            .frame(width: 110, height: 32)
                            .overlay(
                                Text("Safari")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.primary.opacity(0.85))   // auto color
                            )
                    }
                    .opacity(glassOpacity)
                    .shadow(color: Color.primary.opacity(0.15), radius: 12)   // auto shadow color
                    .offset(y: dragOffset)

                Spacer()
            }

            // MARK: - Close Button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)                   // auto color
                            .padding(10)
                            .background(
                                Circle().fill(.thinMaterial)            // auto material
                            )
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)

                    Spacer()
                }
                Spacer()
            }
        }
        .gesture(
            DragGesture().onChanged { value in
                dragOffset = value.translation.height / 10
                glassOpacity = max(0.2, 1 - value.translation.height / 300)
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.4)) {
                    dragOffset = 0
                    glassOpacity = 1.0
                }
            }
        )
    }
}
