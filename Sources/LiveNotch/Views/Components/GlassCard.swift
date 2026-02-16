import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 💎 GlassCard — Liquid Glass Foundation
// ═══════════════════════════════════════════════════
// Multi-layer glassmorphism with breathing animation,
// adaptive borders, and parallax-ready depth.
//
// Usage:
//   GlassCard { Text("Content") }
//   GlassCard(cornerRadius: 16, breathes: false) { ... }
//   GlassCard(accent: DS.Colors.warmCopper) { ... }

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let breathes: Bool
    let accent: Color?
    let padding: CGFloat
    
    @State private var breathScale: CGFloat = 1.0
    @State private var borderGlow: CGFloat = 0.15
    
    init(
        cornerRadius: CGFloat = 20,
        breathes: Bool = true,
        accent: Color? = nil,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.breathes = breathes
        self.accent = accent
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(glassStroke)
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
            .shadow(color: (accent ?? DS.Colors.champagneGold).opacity(0.06), radius: 30, x: 0, y: 5)
            .scaleEffect(breathScale)
            .onAppear {
                guard breathes else { return }
                withAnimation(DS.Anim.breathe) {
                    breathScale = 1.015
                }
                withAnimation(DS.Anim.breathe.delay(0.5)) {
                    borderGlow = 0.25
                }
            }
    }
    
    // ── Multi-layer glass background ──
    private var glassBackground: some View {
        ZStack {
            // Layer 1: System blur material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // Layer 2: Depth gradient (top-left light → bottom-right transparent)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Colors.glassLayer1,
                            DS.Colors.glassLayer2,
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Layer 3: Inner radial highlight (simulates refraction)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            (accent ?? DS.Colors.champagneGold).opacity(0.04),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
            
            // Layer 4: Subtle noise/texture via inner shadow
            RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                .fill(DS.Colors.glassLayer3)
                .padding(1)
        }
    }
    
    // ── Adaptive breathing border ──
    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(borderGlow),
                        Color.white.opacity(borderGlow * 0.4),
                        (accent ?? DS.Colors.champagneGold).opacity(borderGlow * 0.6),
                        Color.white.opacity(borderGlow * 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: breathes ? 1.0 + (breathScale - 1.0) * 30 : 1.0 // 1.0 → ~1.5pt
            )
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🔮 GlassCard Variants
// ═══════════════════════════════════════════════════

extension GlassCard where Content == AnyView {
    /// Compact glass card for grid items (smaller radius, no breathing)
    static func compact<C: View>(
        accent: Color? = nil,
        @ViewBuilder content: () -> C
    ) -> GlassCard<AnyView> {
        GlassCard<AnyView>(
            cornerRadius: DS.Radius.xl,
            breathes: false,
            accent: accent,
            padding: DS.Space.md
        ) {
            AnyView(content())
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 💧 Liquid Glass View Modifier
// ═══════════════════════════════════════════════════
// Lightweight modifier for views that need glass treatment
// without the full GlassCard wrapper.
//
// Usage:
//   VStack { ... }.liquidGlass()
//   VStack { ... }.liquidGlass(cornerRadius: 16, accent: .blue)

struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let accent: Color?
    let intensity: Double  // 0.0 = subtle, 1.0 = full
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08 * intensity),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if let accent = accent {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accent.opacity(0.05 * intensity), .clear],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12 * intensity), lineWidth: 0.8)
            )
    }
}

extension View {
    /// Apply liquid glass treatment to any view
    func liquidGlass(
        cornerRadius: CGFloat = DS.Radius.xl,
        accent: Color? = nil,
        intensity: Double = 1.0
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            accent: accent,
            intensity: intensity
        ))
    }
}

// ═══════════════════════════════════════════════════
// MARK: - ✨ Scale Button Style (Premium Press)
// ═══════════════════════════════════════════════════
// Replaces generic button presses with silk-physics feedback.

struct UltraButtonStyle: ButtonStyle {
    let haptic: Bool
    
    init(haptic: Bool = true) {
        self.haptic = haptic
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DS.Anim.springFast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic {
                    HapticManager.shared.play(.button)
                }
            }
    }
}
