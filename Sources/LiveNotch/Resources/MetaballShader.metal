#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// ═══════════════════════════════════════════════════
// MARK: - 🫧 Metaball Gooey Shader
// ═══════════════════════════════════════════════════
//
// Creates the "mercury drop" gooey effect where adjacent
// UI elements visually merge when they approach each other.
//
// Technique: lightweight blur → alpha threshold → smoothstep edge
// Applied as a [[stitchable]] layerEffect to SwiftUI views.
//
// The gooey effect works by:
// 1. Sampling nearby pixels (small Gaussian kernel)
// 2. Thresholding the alpha channel (sharp merge boundary)
// 3. Smoothstep anti-aliasing for organic edges

// ── Gaussian blur weight function ──
float gaussianWeight(float2 offset, float sigma) {
    return exp(-(offset.x * offset.x + offset.y * offset.y) / (2.0 * sigma * sigma));
}

// ── The Gooey Shader ──
// strength: controls how aggressively elements merge (higher = more gooey)
// radius: blur sample radius in pixels

[[ stitchable ]] half4 metaballGooey(
    float2 position,
    SwiftUI::Layer layer,
    float strength
) {
    // Adaptive radius based on strength
    float radius = clamp(strength * 0.5, 4.0, 30.0);
    float sigma = radius * 0.4;
    
    // ── Phase 1: Blur accumulation ──
    // Sample in a small grid around the current pixel
    half4 blurred = half4(0.0);
    float totalWeight = 0.0;
    
    // 9-tap cross kernel (fast, good enough for gooey)
    // Horizontal + vertical + diagonals
    float2 offsets[9] = {
        float2(0, 0),
        float2(-radius, 0), float2(radius, 0),
        float2(0, -radius), float2(0, radius),
        float2(-radius * 0.7, -radius * 0.7), float2(radius * 0.7, -radius * 0.7),
        float2(-radius * 0.7, radius * 0.7), float2(radius * 0.7, radius * 0.7)
    };
    
    for (int i = 0; i < 9; i++) {
        float w = gaussianWeight(offsets[i], sigma);
        blurred += layer.sample(position + offsets[i]) * w;
        totalWeight += w;
    }
    
    blurred /= totalWeight;
    
    // ── Phase 2: Alpha threshold (the gooey merge) ──
    // Where blurred alpha > threshold → solid (merge zone)
    // Where blurred alpha < threshold → transparent (separation)
    float threshold = 0.5;
    float edge = 0.02;  // Anti-alias width
    
    float gooeyAlpha = smoothstep(threshold - edge, threshold + edge, float(blurred.a));
    
    // ── Phase 3: Reconstruct color ──
    // Use the original pixel color but with the gooey alpha
    half4 original = layer.sample(position);
    
    // Blend: keep original color where visible, use blurred in merge zones
    half3 finalColor = mix(blurred.rgb, original.rgb, half(original.a > 0.5 ? 1.0 : 0.0));
    
    return half4(finalColor, half(gooeyAlpha));
}
