import SwiftUI
import UIKit
import CoreImage

extension UIImage {
    func makeThreadSafe() -> UIImage? {
        defer { UIGraphicsEndImageContext() }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

