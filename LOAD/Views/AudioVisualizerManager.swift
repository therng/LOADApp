import SwiftUI
import Combine

@MainActor
class AudioVisualizerManager: ObservableObject {
    static let barCount = 4
    
    @Published var audioLevels: [Float] = Array(repeating: 0.2, count: barCount)
    
    private var timer: AnyCancellable?
    
    func start() {
        // Ensure no existing timer is running to avoid duplicates
        stop()
        
        // Create a timer that fires every 0.2 seconds for a fluid animation
        timer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.randomizeLevels()
            }
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        
        // Animate back to a resting state
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            audioLevels = Array(repeating: 0.2, count: Self.barCount)
        }
    }
    
    private func randomizeLevels() {
        // Generate a new set of random levels for the bars
        let newLevels = (0..<Self.barCount).map { _ in Float.random(in: 0.2...1.0) }
        
        // Animate the transition to the new levels
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            self.audioLevels = newLevels
        }
    }
}

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
    }
}
