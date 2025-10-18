//
//  GlassIcon.swift
//  LOAD
//
//  Created by Supachai Thawatchokthavee on 31/10/25.
//


import SwiftUI

struct GlassIcon: View {
    let symbolName: String   // "music.note.list.circle.fill"

    var body: some View {
        ZStack {
            // กล่องแก้ว
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
                .overlay( // เส้นไฮไลท์ด้านบน
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        startPoint: .top, endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .blendMode(.screen)
                )

            // สัญลักษณ์
            Image(systemName: symbolName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white) // หรือ .white.opacity(0.9)
                .font(.system(size: 92, weight: .regular, design: .default))
                .shadow(radius: 6)
        }
        .frame(width: 180, height: 180)
    }
}

#Preview {
    GlassIcon(symbolName: "music.note.list.circle.fill")
}