import SwiftUI

struct RealtimeAudioWaveView: View {
    @EnvironmentObject var player: AudioPlayerService
    @StateObject private var visualizer = AudioVisualizerManager()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<AudioVisualizerManager.barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(
                        width: 3,
                        height: max(CGFloat(visualizer.audioLevels[index]) * 22, 4)
                    )
            }
        }
        .frame(width: 24, height: 24, alignment: .center)
        .onAppear {
            visualizer.start()
        }
        .onDisappear {
            visualizer.stop()
        }
    }
}
