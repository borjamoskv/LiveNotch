import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🧊 AnimatedBorderView — Electric AngularGradient Border
// Ported from OnyxNotch — Adapts glow color by notch state
// ═══════════════════════════════════════════════════

struct AnimatedBorderView: View {
    @ObservedObject var stateMachine = NotchStateMachine.shared
    @State private var glowPhase: Double = 0
    
    /// The color to glow — adapts by state or can be overridden
    var glowColor: Color = DS.Colors.cyan
    var lineWidth: CGFloat = 1.0
    var cornerRadius: CGFloat = DS.Radius.xxl
    
    /// Intensity multiplier based on state
    private var glowIntensity: Double {
        switch stateMachine.state {
        case .expanded:  return 1.0
        case .sending:   return 1.0
        case .delivery:  return 0.9
        case .peek:      return 0.7
        case .audioWake: return 0.5
        case .idle:      return 0.15
        }
    }
    
    /// Whether to show the energized (thicker) border
    private var isActive: Bool {
        stateMachine.state != .idle
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: [
                        glowColor.opacity(glowIntensity),
                        glowColor.opacity(glowIntensity * 0.3),
                        Color.clear,
                        Color.clear,
                        glowColor.opacity(glowIntensity * 0.5),
                        glowColor.opacity(glowIntensity),
                    ]),
                    center: .center,
                    startAngle: .degrees(glowPhase),
                    endAngle: .degrees(glowPhase + 360)
                ),
                lineWidth: isActive ? 1.5 : lineWidth
            )
            .blur(radius: isActive ? 1.5 : 0.5)
            .overlay(
                // Inner crisp edge
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        glowColor.opacity(glowIntensity * 0.3),
                        lineWidth: 0.5
                    )
            )
            .onAppear {
                // Continuous rotation animation
                withAnimation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
                ) {
                    glowPhase = 360
                }
            }
            .allowsHitTesting(false) // Overlay only, no interaction
    }
}

// ═══════════════════════════════════════════════════
// MARK: - ViewModifier for easy application
// ═══════════════════════════════════════════════════

struct AnimatedBorderModifier: ViewModifier {
    var color: Color = DS.Colors.cyan
    var cornerRadius: CGFloat = DS.Radius.xxl
    
    func body(content: Content) -> some View {
        content.overlay(
            AnimatedBorderView(
                glowColor: color,
                cornerRadius: cornerRadius
            )
        )
    }
}

extension View {
    /// Adds an animated electric border around any view
    func animatedBorder(
        color: Color = DS.Colors.cyan,
        cornerRadius: CGFloat = DS.Radius.xxl
    ) -> some View {
        modifier(AnimatedBorderModifier(color: color, cornerRadius: cornerRadius))
    }
}
