import SwiftUI

struct HoldRingView: View {
    let progress: CGFloat
    
    var body: some View {
        Circle()
            // trim draws from 0 up to `progress`
            .trim(from: 0.0, to: progress)
            .stroke(
                Color.white,
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )
            // Rotate so it starts drawing from 12 o'clock
            .rotationEffect(Angle(degrees: -90))
            // The drawing animation itself is usually driven by the parent tracking the hold duration,
            // but we can ensure changes to `progress` are animated here:
            .animation(.linear(duration: 0.1), value: progress)
    }
}
