import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Field {
    case suit
    case rank
}

// Define a FocusedValueKey and expose it on FocusedValues so we can read/write it.
private struct FieldFocusedValueKey: FocusedValueKey {
    typealias Value = Field
}

extension FocusedValues {
    var field: Field? {
        get { self[FieldFocusedValueKey.self] }
        set { self[FieldFocusedValueKey.self] = newValue }
    }
}

struct KeyboardBarDemo: View {
    @State private var suitText: String = ""
    @State private var rankText: String = ""

    @FocusedValue(\.field) var field: Field?

    var body: some View {
        HStack {
            TextField("Suit", text: $suitText)
                .focusedValue(\.field, .suit)
            TextField("Rank", text: $rankText)
                .focusedValue(\.field, .rank)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if field == .suit {
                    Button("♣️", action: {})
                    Button("♥️", action: {})
                    Button("♠️", action: {})
                    Button("♦️", action: {})
                }
                DoneButton()
            }
        }
    }
}

struct DoneButton: View {
    var body: some View {
        #if canImport(UIKit)
        Button("Done") {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        #else
        Button("Done") { }
        #endif
    }
}

#Preview {
    NavigationStack {
        KeyboardBarDemo()
    }
}

