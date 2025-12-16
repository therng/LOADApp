import SwiftUI
import AVKit
import UIKit

struct AirPlayRoutePickerView: UIViewRepresentable {
    var activeTintColor: UIColor = .label
    var tintColor: UIColor = .label
    var prioritizesVideoDevices: Bool = false

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.prioritizesVideoDevices = prioritizesVideoDevices
        view.activeTintColor = activeTintColor
        view.tintColor = tintColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.prioritizesVideoDevices = prioritizesVideoDevices
        uiView.activeTintColor = activeTintColor
        uiView.tintColor = tintColor
    }
}
