//
//  AppLogoView.swift
//  LOAD
//
//  Created by Supachai Thawatchokthavee on 31/10/25.
//

import SwiftUI

struct AppLogoView: View {
    private enum Metrics {
        static let cornerRadius: CGFloat = 28
        static let size: CGFloat = 160
        static let iconSize: CGFloat = 72
        static let shadowRadius: CGFloat = 12
        static let strokeOpacity: Double = 0.25

        static let pressedScale: CGFloat = 0.94
        static let glowMaxOpacity: Double = 0.35
        static let glowBlur: CGFloat = 24
    }

    @State private var isPressed: Bool = false
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Liquid glass background (iOS 26) with fallback
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .glassEffect(.regular, in: .rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
                    .shadow(radius: Metrics.shadowRadius)
            } else {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                            .stroke(.white.opacity(Metrics.strokeOpacity), lineWidth: 1)
                    )
                    .shadow(radius: Metrics.shadowRadius)
            }

            // Glow overlay to highlight tap
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(glowOpacity))
                .blur(radius: Metrics.glowBlur)
                .allowsHitTesting(false)

            Image(systemName: "music.note.list.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .font(.system(size: Metrics.iconSize))
        }
        .frame(width: Metrics.size, height: Metrics.size)
        .scaleEffect(isPressed ? Metrics.pressedScale : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("App Logo")
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .onTapGesture {
            // Tap feedback animation: quick glow + bounce
            withAnimation(.easeOut(duration: 0.08)) {
                isPressed = true
                glowOpacity = Metrics.glowMaxOpacity
            }
            // release
            withAnimation(.easeOut(duration: 0.18).delay(0.08)) {
                isPressed = false
            }
            // fade glow
            withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                glowOpacity = 0
            }
            // Optional: Haptic
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

#Preview {
    AppLogoView()
}
