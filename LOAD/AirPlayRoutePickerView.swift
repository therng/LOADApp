import SwiftUI
import AVKit

struct AirPlayRoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        // Optional: customize button appearance via tintColor
        if #available(iOS 13.0, *) {
            view.tintColor = UIColor.label
            view.activeTintColor = UIColor.systemBlue
        }
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No dynamic updates needed for now
    }
}
