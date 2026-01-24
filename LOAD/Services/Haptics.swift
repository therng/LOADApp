import UIKit
import SwiftUI
import CoreHaptics

/// A dedicated engine for managing haptic feedback generators.
/// Maintains references to generators to minimize latency (pre-warming).
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()
    
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    
    private let supportsHaptics: Bool
    
    private init() {
        // specific check to avoid log spam on devices/simulators that lack hardware support
        // (e.g. iPads, Macs, or Simulator runtime issues)
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        self.supportsHaptics = capabilities.supportsHaptics
        
        if supportsHaptics {
            // Pre-warm the most common generators
            let sGen = UISelectionFeedbackGenerator()
            sGen.prepare()
            self.selectionGenerator = sGen
            
            let nGen = UINotificationFeedbackGenerator()
            nGen.prepare()
            self.notificationGenerator = nGen
        }
    }
    
    func playSelection() {
        guard supportsHaptics else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }
    
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard supportsHaptics else { return }
        notificationGenerator?.notificationOccurred(type)
        notificationGenerator?.prepare()
    }
    
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard supportsHaptics else { return }
        
        if let generator = impactGenerators[style] {
            generator.impactOccurred()
            generator.prepare()
        } else {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
            generator.prepare() // Prepare for next use
            impactGenerators[style] = generator
        }
    }
}

/// Static accessor for Haptics to ensure easy usage throughout the app.
/// Checks for main thread and simulator environment.
enum Haptics {
    static func selection() {
        #if !targetEnvironment(simulator)
        Task { @MainActor in
            HapticEngine.shared.playSelection()
        }
        #endif
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if !targetEnvironment(simulator)
        Task { @MainActor in
            HapticEngine.shared.playNotification(type)
        }
        #endif
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if !targetEnvironment(simulator)
        Task { @MainActor in
            HapticEngine.shared.playImpact(style)
        }
        #endif
    }
}
