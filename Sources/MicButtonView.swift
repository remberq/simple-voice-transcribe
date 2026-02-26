import SwiftUI

struct MicButtonView: View {
    @ObservedObject var controller: OverlayController
    
    // Hover State
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Background Shape
            Circle()
                .fill(backgroundColor)
                .frame(width: 56, height: 56)
            
            // 1. The main mic icon — only in idle/error
            if controller.state == .idle || controller.state == .error {
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(iconColor)
                    // Specular Highlight (Glass Sheen) applied as an overlay mask
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(isHovering ? 0.6 : 0.0), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .mask(
                            Image(systemName: iconName)
                                .resizable()
                                .scaledToFit()
                        )
                    )
            }
            
            // 2. Live equalizer bars when recording
            if controller.state == .recording {
                EqualizerBarsView(recorder: RecorderService.shared)
                    .allowsHitTesting(false)
            }
            
            // 3. Spinner for Transcribing
            if controller.state == .transcribing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 80, height: 80, alignment: .center)
        .contentShape(Circle())
        // Subtle Glow / Depth
        .shadow(
            color: shadowColor,
            radius: isHovering ? 6 : 3,
            x: 0,
            y: isHovering ? 3 : 1
        )
        .scaleEffect(isHovering ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        // Hover Tracking
        .onHover { hovering in
            self.isHovering = hovering
        }
        // Simple tap: idle → recording, recording → stop
        .onTapGesture {
            switch controller.state {
            case .idle, .error:
                controller.handleTap()
            case .recording:
                controller.handleStop()
            default:
                break
            }
        }
    }
    
    // MARK: - Aesthetics Maps
    
    private var backgroundColor: Color {
        switch controller.state {
        case .idle: return Color(nsColor: .windowBackgroundColor).opacity(0.85)
        case .recording: return Color.red.opacity(0.85)
        case .transcribing: return Color.blue.opacity(0.85)
        case .error: return Color.red.opacity(0.9)
        default: return Color(nsColor: .windowBackgroundColor).opacity(0.85)
        }
    }
    
    private var iconName: String {
        switch controller.state {
        case .idle: return "mic.fill"
        case .recording: return "mic.fill"
        case .transcribing: return "hourglass" 
        case .error: return "exclamationmark.triangle.fill"
        default: return "mic.fill"
        }
    }
    
    private var iconColor: Color {
        switch controller.state {
        case .idle: return .blue
        case .recording: return .clear // Only equalizer shows
        case .transcribing: return .clear // Hidden behind spinner
        case .error: return .white
        default: return .white
        }
    }
    
    private var shadowColor: Color {
        switch controller.state {
        case .idle: return Color.black.opacity(0.2)
        case .recording: return .red.opacity(0.6)
        case .transcribing: return .blue.opacity(0.5)
        case .error: return .red.opacity(0.6)
        default: return Color.black.opacity(0.2)
        }
    }
}
