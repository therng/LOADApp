import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let isPlaying: Bool
    let animationDuration: Animation
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animationDuration, value: progress)
            
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 30, height: 30)
    }
}
