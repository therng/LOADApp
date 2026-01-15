import SwiftUI
import Combine
import AVFoundation

@MainActor
class AudioVisualizerManager: ObservableObject {
    // จำนวนแท่งกราฟ (Apple Lock Screen ใช้ 4 แท่งหลัก)
    static let barCount = 4
    
    @Published var audioLevels: [Float] = Array(repeating: 0.2, count: AudioVisualizerManager.barCount)
    
    private var timer: AnyCancellable?
    private var isAnalyzing = false
    private var phase: Double = 0.0
    
    func startAnalyzing(isPlaying: Bool) {
        guard isPlaying else {
            stopAnalyzing()
            return
        }
        
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        // Refresh rate สำหรับความลื่นไหลระดับ iOS
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateLockScreenStyleLevels()
            }
    }
    
    func stopAnalyzing() {
        isAnalyzing = false
        timer?.cancel()
        timer = nil
        
        // กลับสู่สถานะหยุดนิ่ง (แท่งสั้นเท่ากัน)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            audioLevels = Array(repeating: 0.2, count: AudioVisualizerManager.barCount)
        }
    }
    
    private func updateLockScreenStyleLevels() {
        var currentLevels = audioLevels
        phase += 0.5
        
        for i in 0..<currentLevels.count {
            // จำลองลอจิกคลื่นเสียงของ Apple ที่แต่ละแท่งขยับไม่พร้อมกัน
            let speed = Double(i + 1) * 0.5
            let wave = abs(sin(phase + speed))
            
            // สุ่มเล็กน้อยให้ดูมีความเป็นธรรมชาติ (Organic)
            let random = Float.random(in: 0.2...0.9)
            let target = min(1.0, max(0.2, Float(wave) * random))
            
            currentLevels[i] = target
        }
        
        // ใช้ Spring animation ที่มีความหนืดพอดีแบบ iOS
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            self.audioLevels = currentLevels
        }
    }
}

struct RealtimeAudioWaveView: View {
    @EnvironmentObject var player: AudioPlayerService
    @StateObject private var visualizer = AudioVisualizerManager()
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<visualizer.audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary) // สีจะเปลี่ยนตาม Light/Dark mode อัตโนมัติ
                    .frame(
                        width: 3, // แท่งบางๆ แบบ iOS
                        height: max(CGFloat(visualizer.audioLevels[index]) * 22, 4)
                    )
            }
        }
        .frame(width: 24, height: 24) // ขนาด Compact สำหรับใส่ในแถบควบคุม
        .onAppear {
            if player.isPlaying { visualizer.startAnalyzing(isPlaying: true) }
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            visualizer.startAnalyzing(isPlaying: isPlaying)
        }
        .onChange(of: player.currentTrack) { _, _ in
            visualizer.stopAnalyzing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.isPlaying {
                    visualizer.startAnalyzing(isPlaying: true)
                }
            }
        }
    }
}
