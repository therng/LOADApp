import SwiftUI
import UIKit

extension UIImage {
    func makeThreadSafe() -> UIImage? {
        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension Color {
    /// Returns a version of the color toned to work better as a background.
    /// Bright colors are darkened slightly; dark colors are lightened slightly.
    nonisolated func tonedForBackground() -> Color {
        // Convert to RGBA via UIColor
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Perceived luminance (sRGB)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

        // Blend factor determines how much to move toward target (black/white)
        let blend: CGFloat = 0.18

        let tonedRed: CGFloat
        let tonedGreen: CGFloat
        let tonedBlue: CGFloat

        if luminance > 0.7 {
            // Too bright: blend slightly toward black
            tonedRed   = r * (1 - blend)
            tonedGreen = g * (1 - blend)
            tonedBlue  = b * (1 - blend)
        } else if luminance < 0.3 {
            // Too dark: blend slightly toward white
            tonedRed   = r + (1 - r) * blend
            tonedGreen = g + (1 - g) * blend
            tonedBlue  = b + (1 - b) * blend
        } else {
            // Mid-range: small desaturation for subtlety
            let gray = (r + g + b) / 3
            let desat: CGFloat = 0.12
            tonedRed   = r + (gray - r) * desat
            tonedGreen = g + (gray - g) * desat
            tonedBlue  = b + (gray - b) * desat
        }

        let tonedColor = UIColor(red: tonedRed, green: tonedGreen, blue: tonedBlue, alpha: a)
        return Color(tonedColor)
    }
}
