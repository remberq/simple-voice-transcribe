import SwiftUI

enum OverlayState {
    case idle
    case recording
    case paused
    case transcribing
    case error
}

struct OverlayView: View {
    @ObservedObject var controller: OverlayController
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Mic Button handles its own states, hover, and gestures
            MicButtonView(controller: controller)
            
            // Render toast underneath the circle if active
            if let toastMsg = controller.toastMessage {
                ToastView(message: toastMsg)
                    .padding(.top, 4)
            }
        }
        // Small padding to prevent clipping of the shadow and hover scale
        .padding(16)
    }
}
