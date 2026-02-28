import SwiftUI

extension View {
    /// A backward-compatible `onChange` modifier that avoids deprecation warnings on macOS 14 
    /// while still compiling successfully for macOS 13 targets (like SPM test suites).
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            // Fallback on earlier versions (macOS 13)
            self.onChange(of: value, perform: action)
        }
    }
}
