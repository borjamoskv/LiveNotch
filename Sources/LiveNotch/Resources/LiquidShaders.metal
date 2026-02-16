#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h> // Include SwiftUI Metal header

using namespace metal;

// ── Distance Functions ──

// Box SDF
float sdRoundedBox(float2 p, float2 b, float4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x  = (p.y > 0.0) ? r.x  : r.y;
    float2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

// Simple Hash for Grain
float hash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// Circle SDF
float sdCircle(float2 p, float r) {
    return length(p) - r;
}

// Smooth Minimum
float smin(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// ── The Shader ──

[[ stitchable ]] half4 liquidNotch(
    float2 position,
    half4 color, // Required input color from the view
    float4 layerBounds, // (x, y, width, height) passed as argument
    float2 mousePos,    // Mouse position relative to center
    float2 notchSize,   // Width, Height of the base notch
    float4 cornerRadii, // Vector (top-right, bottom-right, top-left, bottom-left)
    float liquidStrength,
    half4 activeColor   // The target color of the liquid
) {
    // 1. Normalize coordinates
    // layerBounds.zw is width, height.
    float2 size = layerBounds.zw;
    float2 p = position - (size * 0.5); // Center (0,0) around the middle of the view
    
    // 2. Define Notch Shape
    // Notch is at the top center.
    // In Metal coordinate system (top-left is usually 0,0 but here we centered 'p'),
    // SwiftUI coordinates: y increases downwards.
    // Let's assume standard behavior: we want the notch at the top edge.
    // If view height is 'size.y', top is -size.y/2.
    
    // Position notch at the top of the view
    float notchY = -size.y * 0.5 + (notchSize.y * 0.5);
    float2 notchCenter = float2(0, notchY);
    
    float2 notchHalfSize = notchSize * 0.5;
    float dNotch = sdRoundedBox(p - notchCenter, notchHalfSize, cornerRadii);
    
    // 3. Mouse Attractor
    // Force mouse pos to be relative to center (handled in Swift)
    float dMouse = sdCircle(p - mousePos, 30.0); // 30px radius for the "finger"
    
    // 4. Blend
    float dLiquid = smin(dNotch, dMouse, liquidStrength);
    
    // 5. Render
    // Antialiased shape
    float alpha = 1.0 - smoothstep(0.0, 1.5, dLiquid);
    
    // ── ALCOVE Glossy Black Effect ──
    // Normalized position within the notch shape (0 = top, 1 = bottom)
    float2 pInNotch = (p - notchCenter + notchHalfSize) / (notchSize + 0.001);
    float ny = clamp(pInNotch.y, 0.0, 1.0);
    float nx = clamp(pInNotch.x, 0.0, 1.0);
    
    // Top-edge specular highlight (whisper of lacquer shine)
    float topShine = exp(-ny * 10.0) * 0.04; // Barely visible at top edge
    
    // Subtle center gloss (almost invisible curved reflection)
    float centerGloss = exp(-pow((nx - 0.5) * 2.0, 2.0) * 4.0) * exp(-ny * 5.0) * 0.015;
    
    // Bottom-edge ambient lift (imperceptible)
    float bottomAmbient = smoothstep(0.8, 1.0, ny) * 0.008;
    
    // Combine: base color + micro-glossy highlights (DEEP BLACK dominant)
    float gloss = (topShine + centerGloss + bottomAmbient) * alpha;
    
    // ── Industrial Noir Grain ──
    float grain = (hash(position + float2(1.0, 1.0)) - 0.5) * 0.012; // Static organic grain
    
    half3 finalColor = activeColor.rgb + half3(gloss + grain, gloss + grain, gloss + grain);
    
    return half4(finalColor, alpha * activeColor.a);
}

// ── Chromatic Aberration (Thinking Mode) ──
[[ stitchable ]] half4 chromaticAberration(
    float2 position,
    SwiftUI::Layer layer,
    float strength
) {
    float2 offset = float2(strength, 0);
    half r = layer.sample(position - offset).r;
    half g = layer.sample(position).g;
    half b = layer.sample(position + offset).b;
    half a = layer.sample(position).a;
    return half4(r, g, b, a);
}
