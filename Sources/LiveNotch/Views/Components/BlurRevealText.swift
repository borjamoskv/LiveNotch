import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🌫️ BlurRevealText — Text Materialization from Blur
// Ported from OnyxNotch — Characters resolve from blur like a hologram
// ═══════════════════════════════════════════════════

struct BlurRevealText: View {
    let text: String
    let font: Font
    let color: Color
    let staggerDelay: Double
    
    @State private var revealed = false
    
    init(
        _ text: String,
        font: Font = DS.Fonts.labelSemi,
        color: Color = DS.Colors.textPrimary,
        staggerDelay: Double = 0.03
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.staggerDelay = staggerDelay
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(font)
                    .foregroundStyle(color)
                    .blur(radius: revealed ? 0 : 8)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.8)
                    .animation(
                        DS.NotchSpring.liquid.delay(Double(index) * staggerDelay),
                        value: revealed
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                revealed = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - BlurRevealModifier — For existing Text views
// ═══════════════════════════════════════════════════

struct BlurRevealModifier: ViewModifier {
    @State private var revealed = false
    var delay: TimeInterval = 0
    
    func body(content: Content) -> some View {
        content
            .blur(radius: revealed ? 0 : 10)
            .opacity(revealed ? 1 : 0)
            .scaleEffect(revealed ? 1 : 0.85)
            .animation(DS.NotchSpring.liquid.delay(delay), value: revealed)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
                    revealed = true
                }
            }
    }
}

extension View {
    /// Applies a blur-reveal materialization effect
    func blurReveal(delay: TimeInterval = 0) -> some View {
        modifier(BlurRevealModifier(delay: delay))
    }
}
