import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 📼 Tape Deck VU Meter
// ═══════════════════════════════════════════════════
// Analog VU meter with fast attack, slow release.
// Used by Tape Deck theme. Hardware aesthetic.

struct TapeDeckVUMeter: View {
    @ObservedObject var pulse = AudioPulseEngine.shared
    var color: Color = Color(red: 0.9, green: 0.6, blue: 0.2) // Warm amber
    
    @State private var displayLevel: CGFloat = 0
    @State private var peakLevel: CGFloat = 0
    @State private var peakHoldTimer: Int = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.04))
                
                // VU fill (fast attack, slow release)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.5),
                                displayLevel > 0.8 ? Color.red.opacity(0.7) : color.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * displayLevel))
                
                // Peak indicator (thin line)
                if peakLevel > 0.05 {
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * peakLevel - 1)
                }
                
                // Scale marks
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i >= 8 ? 0.15 : 0.05))
                            .frame(width: 0.5)
                        if i < 9 { Spacer() }
                    }
                }
            }
        }
        .frame(height: 4)
        .onChange(of: pulse.level) { _, newLevel in
            let target = CGFloat(newLevel)
            
            // Fast attack
            if target > displayLevel {
                withAnimation(DS.Spring.micro) {
                    displayLevel = target
                }
            } else {
                // Slow release (ballistic decay)
                withAnimation(DS.Spring.soft) {
                    displayLevel = target
                }
            }
            
            // Peak hold
            if target > peakLevel {
                peakLevel = target
                peakHoldTimer = 30 // Hold for ~1 second at 30fps
            } else {
                peakHoldTimer -= 1
                if peakHoldTimer <= 0 {
                    withAnimation(DS.Spring.soft) {
                        peakLevel = max(target, peakLevel * 0.95)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎛️ Transport Controls (Hardware Look)
// ═══════════════════════════════════════════════════

struct TapeDeckTransportControls: View {
    var onPrevious: () -> Void
    var onPlayPause: () -> Void
    var onNext: () -> Void
    var isPlaying: Bool
    var color: Color = Color(red: 0.9, green: 0.6, blue: 0.2)
    
    var body: some View {
        HStack(spacing: 12) {
            // Rewind (hardware style: ◀◀)
            transportButton(icon: "backward.fill") { onPrevious() }
            
            // Play/Pause (larger, recessed look)
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 32, height: 32)
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                        .frame(width: 32, height: 32)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color.opacity(0.8))
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            
            // Forward (hardware style: ▶▶)
            transportButton(icon: "forward.fill") { onNext() }
        }
    }
    
    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.02)))
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
