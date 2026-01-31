import SwiftUI

struct ArtworkView: View {
    let image: UIImage?
    var size: CGFloat? = nil
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 0
    var iconSize: CGFloat = 40 // Default icon size for placeholder
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: iconSize))
                            .foregroundColor(.secondary)
                    }
            }
        }
        .ifLet(size) { view, size in
            view.frame(width: size, height: size)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .ifLet(shadowRadius > 0) { view in
             view.shadow(color: .black.opacity(0.25), radius: shadowRadius, y: 5)
        }
    }
}

extension View {
    @ViewBuilder
    func ifLet<Content: View, T>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ifLet(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
