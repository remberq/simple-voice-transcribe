import SwiftUI
import Combine

struct EqualizerBarsView: View {
    @ObservedObject var recorder: RecorderService
    
    // Each bar has a slightly different response character for visual richness
    private let barCount = 5
    private let barMultipliers: [CGFloat] = [0.7, 1.0, 0.85, 0.95, 0.75]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                LiveBar(
                    level: recorder.audioLevel,
                    multiplier: barMultipliers[index]
                )
            }
        }
        .frame(width: 30, height: 28)
    }
}

struct LiveBar: View {
    let level: CGFloat
    let multiplier: CGFloat
    
    private let minHeight: CGFloat = 4.0
    private let maxHeight: CGFloat = 28.0
    
    var body: some View {
        let barHeight = minHeight + (maxHeight - minHeight) * min(level * multiplier, 1.0)
        
        Capsule()
            .fill(Color.white)
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.08), value: level)
    }
}
