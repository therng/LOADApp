import SwiftUI
import UIKit
import CoreImage

extension UIImage {
    nonisolated func averageColor() -> Color? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return Color(
            UIColor(
                red: CGFloat(bitmap[0]) / 255,
                green: CGFloat(bitmap[1]) / 255,
                blue: CGFloat(bitmap[2]) / 255,
                alpha: 1
            )
        )
    }
}
extension UIColor {
    nonisolated func tonedForBackground() -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let toned = UIColor(
            hue: hue,
            saturation: min(saturation * 1.2, 0.9),
            brightness: min(brightness * 0.75, 0.55),
            alpha: 1
        )

        return Color(toned)
    }
}

extension NSNotification.Name {
    static let showBanner = NSNotification.Name("showBanner")
}
