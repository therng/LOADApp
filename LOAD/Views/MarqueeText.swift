import SwiftUI

public struct MarqueeText: View {

    // MARK: - Public API
    @Environment(\.displayScale) private var displayScale
    public let text: String
    public let font: Font
    public let color: Color
    public let isActive: Bool
    public let speed: Double
    public let spacing: CGFloat
    public let alignment: Alignment

    public init(
        text: String,
        font: Font,
        color: Color = .primary,
        isActive: Bool,
        speed: Double = 30,
        spacing: CGFloat = 32,
        alignment: Alignment = .leading
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.isActive = isActive
        self.speed = speed
        self.spacing = spacing
        self.alignment = alignment
    }

    // MARK: - State
    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isScrolling: Bool = false

    private var shouldScroll: Bool {
        isActive && textSize.width > containerWidth && containerWidth > 0
    }

    private var distance: CGFloat {
        textSize.width + spacing
    }

    private var duration: Double {
        max(0.1, Double(distance) / speed)
    }
    
    private var widthEpsilon: CGFloat {
        1.0 / displayScale
    }
    
    private var heightEpsilon: CGFloat {
        1.0 / displayScale
    }
    
    private var measuredHeight: CGFloat {
        max(singleLineHeight, textSize.height)
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: alignment) {
                if shouldScroll {
                    scrollingContent
                } else {
                    staticContent
                }
            }
            .onAppear {
                updateContainerWidth(geo.size.width)
            }
            .onChange(of: geo.size.width) { _, w in
                updateContainerWidth(w)
            }
        }
        .frame(height: measuredHeight)
        .clipped()
        .onAppear { start(forceRestart: true) }
        .onChange(of: isActive) { _, _ in
            start(forceRestart: true)
        }
    }

    // MARK: - Views

    private var staticContent: some View {
        textView
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var scrollingContent: some View {
        HStack(spacing: spacing) {
            textView
            textView
        }
        .offset(x: offset)
    }

    private var textView: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .readSize(updateTextSize)
    }

    // MARK: - Animation

    private func updateTextSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let widthChanged = abs(textSize.width - size.width) >= widthEpsilon
        let heightChanged = abs(textSize.height - size.height) >= heightEpsilon
        guard widthChanged || heightChanged else { return }
        textSize = size
        start(forceRestart: true)
    }

    private func updateContainerWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        guard abs(containerWidth - width) >= widthEpsilon else { return }
        containerWidth = width
        start(forceRestart: false)
    }

    private func start(forceRestart: Bool) {
        guard shouldScroll else {
            if isScrolling {
                isScrolling = false
            }
            setOffsetWithoutAnimation(0)
            return
        }

        if isScrolling && !forceRestart {
            return
        }

        isScrolling = true
        setOffsetWithoutAnimation(0)
        DispatchQueue.main.async {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }

    private func setOffsetWithoutAnimation(_ value: CGFloat) {
        let reset = Transaction(animation: nil)
        withTransaction(reset) {
            offset = value
        }
    }

    private var singleLineHeight: CGFloat {
        24 // stable height, no UIKit
    }
}

private extension View {
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader {
                Color.clear.preference(key: SizeKey.self, value: $0.size)
            }
        )
        .onPreferenceChange(SizeKey.self, perform: onChange)
    }
}

private struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}
