import AVKit
import SwiftUI

struct AirPlayButtonView: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled

    var tintColor: UIColor = .label
    var activeTintColor: UIColor = .systemBlue
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.backgroundColor = .clear
        view.prioritizesVideoDevices = false
        view.tintColor = tintColor
        view.activeTintColor = activeTintColor
        return view
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
