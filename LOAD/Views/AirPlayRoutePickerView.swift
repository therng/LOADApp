import SwiftUI
import AVKit

struct AirPlayRoutePickerView: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.showsVolumeSlider = false
        view.showsRouteButton = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
