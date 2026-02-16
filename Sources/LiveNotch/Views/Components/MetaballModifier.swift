import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🫧 Metaball Gooey View Modifier
// ═══════════════════════════════════════════════════
//
// Wraps any SwiftUI view with the gooey metaball shader.
// Adjacent child elements will visually "merge" like mercury drops
// when they overlap or approach each other.
//
// Usage:
//   HStack(spacing: -10) {
//       Circle().frame(width: 40, height: 40)
//       Circle().frame(width: 40, height: 40)
//   }
//   .metaball(strength: 20)
//
// Performance: Metal-backed via .drawingGroup() + .layerEffect()
// — runs on GPU at display refresh rate.

@available(macOS 14.0, *)
struct MetaballModifier: ViewModifier {
    var strength: CGFloat
    
    func body(content: Content) -> some View {
        content
            .drawingGroup()  // Rasterize to Metal texture
            .layerEffect(
                ShaderLibrary.metaballGooey(
                    .float(Float(strength))
                ),
                maxSampleOffset: CGSize(
                    width: min(strength * 0.5, 30),
                    height: min(strength * 0.5, 30)
                )
            )
    }
}

@available(macOS 14.0, *)
extension View {
    /// Apply the gooey metaball effect to this view's children.
    /// Adjacent elements will visually merge like mercury when close together.
    ///
    /// - Parameter strength: Merge aggressiveness (4–60). Default 20.
    ///   Lower = subtle surface tension. Higher = aggressive merge.
    func metaball(strength: CGFloat = 20) -> some View {
        modifier(MetaballModifier(strength: strength))
    }
}
