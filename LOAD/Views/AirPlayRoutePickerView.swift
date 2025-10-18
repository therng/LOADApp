import SwiftUI
import AVKit

struct AirPlayRoutePickerView: UIViewRepresentable {
    var tintColor: UIColor = .white
    var activeTintColor: UIColor = .systemBlue
    var prioritizesVideoDevices: Bool = false

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = prioritizesVideoDevices
        view.tintColor = tintColor
        view.activeTintColor = activeTintColor
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.prioritizesVideoDevices = prioritizesVideoDevices
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
