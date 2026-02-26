import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.primary)
            // Allow clicks to pass through
            .allowsHitTesting(false)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
