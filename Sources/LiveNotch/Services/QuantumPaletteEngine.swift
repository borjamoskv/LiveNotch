import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - ⚛️ Quantum Palette Engine
// ═══════════════════════════════════════════════════
//
// Extracts 5 color palettes in PARALLEL from album artwork.
// Each palette represents a different chromatic interpretation:
//   .warm        → Shifts hues towards amber/fire
//   .cool        → Shifts hues towards cyan/ice
//   .vibrant     → Maximizes saturation
//   .muted       → Desaturates for noir aesthetic
//   .complementary → Inverts dominant hue for contrast
//
// User selects palette via horizontal swipe gesture.
// Transition between palettes uses spring physics.

@MainActor
final class QuantumPaletteEngine: ObservableObject {
    
    // ── Palette Variants ──
    enum PaletteVariant: String, CaseIterable, Identifiable {
        case warm           = "warm"
        case cool           = "cool"
        case vibrant        = "vibrant"
        case muted          = "muted"
        case complementary  = "complementary"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .warm:           return "flame.fill"
            case .cool:           return "snowflake"
            case .vibrant:        return "sparkles"
            case .muted:          return "moon.fill"
            case .complementary:  return "arrow.triangle.2.circlepath"
            }
        }
        
        var label: String {
            switch self {
            case .warm:           return "WARM"
            case .cool:           return "COOL"
            case .vibrant:        return "VIVID"
            case .muted:          return "NOIR"
            case .complementary:  return "DUAL"
            }
        }
    }
    
    // ── 5-Color Palette ──
    struct ColorPalette: Equatable {
        let dominant: Color
        let secondary: Color
        let accent: Color
        let background: Color
        let highlight: Color
        
        // Gradient shorthand
        var gradient: [Color] { [dominant, secondary, accent] }
        var backgroundGradient: [Color] { [background, dominant.opacity(0.3)] }
        
        static let placeholder = ColorPalette(
            dominant: Color(red: 0.35, green: 0.65, blue: 1.0),
            secondary: Color(red: 0.65, green: 0.35, blue: 1.0),
            accent: Color(red: 1.0, green: 0.6, blue: 0.2),
            background: Color(white: 0.08),
            highlight: Color.white.opacity(0.9)
        )
    }
    
    // ── Published State ──
    @Published var activeVariant: PaletteVariant = .vibrant
    @Published var palettes: [PaletteVariant: ColorPalette] = [:]
    @Published var isExtracting: Bool = false
    @Published var extractionTimeMs: Int = 0
    
    // ── Derived ──
    var activePalette: ColorPalette {
        palettes[activeVariant] ?? .placeholder
    }
    
    // ── Private ──
    private var lastImageHash: Int = 0
    
    // ════════════════════════════════════════
    // MARK: - Parallel Extraction
    // ════════════════════════════════════════
    
    /// Extracts all 5 palettes concurrently from an NSImage
    func extractPalettes(from image: NSImage) {
        let hash = image.tiffRepresentation?.hashValue ?? 0
        guard hash != lastImageHash else { return }
        lastImageHash = hash
        isExtracting = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else {
                await MainActor.run { self?.isExtracting = false }
                return
            }
            
            // Step 1: Extract base colors via k-means clustering
            let baseColors = Self.kMeansClustering(bitmap: bitmap, k: 8)
            
            // Step 2: Generate 5 variants IN PARALLEL
            async let warmPalette = Self.generatePalette(from: baseColors, variant: .warm)
            async let coolPalette = Self.generatePalette(from: baseColors, variant: .cool)
            async let vibrantPalette = Self.generatePalette(from: baseColors, variant: .vibrant)
            async let mutedPalette = Self.generatePalette(from: baseColors, variant: .muted)
            async let complementaryPalette = Self.generatePalette(from: baseColors, variant: .complementary)
            
            let results: [PaletteVariant: ColorPalette] = await [
                .warm: warmPalette,
                .cool: coolPalette,
                .vibrant: vibrantPalette,
                .muted: mutedPalette,
                .complementary: complementaryPalette
            ]
            
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self?.palettes = results
                    self?.isExtracting = false
                    self?.extractionTimeMs = elapsed
                }
            }
        }
    }
    
    /// Select palette by index (for gesture-based selection)
    func selectPalette(at index: Int) {
        let variants = PaletteVariant.allCases
        guard index >= 0, index < variants.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeVariant = variants[index]
        }
        HapticManager.shared.play(.toggle)
    }
    
    /// Cycle to next palette
    func nextPalette() {
        let variants = PaletteVariant.allCases
        guard let idx = variants.firstIndex(of: activeVariant) else { return }
        let next = variants[(idx + 1) % variants.count]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeVariant = next
        }
        HapticManager.shared.play(.toggle)
    }
    
    /// Cycle to previous palette
    func previousPalette() {
        let variants = PaletteVariant.allCases
        guard let idx = variants.firstIndex(of: activeVariant) else { return }
        let prev = variants[(idx - 1 + variants.count) % variants.count]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeVariant = prev
        }
        HapticManager.shared.play(.toggle)
    }
    
    // ════════════════════════════════════════
    // MARK: - K-Means Clustering
    // ════════════════════════════════════════
    
    /// Simplified k-means color clustering on bitmap data
    nonisolated private static func kMeansClustering(bitmap: NSBitmapImageRep, k: Int, iterations: Int = 10) -> [HSBColor] {
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        // Sample pixels (stride for performance)
        let stride = max(1, min(width, height) / 32)
        var pixels: [HSBColor] = []
        pixels.reserveCapacity((width / stride) * (height / stride))
        
        for x in Swift.stride(from: 0, to: width, by: stride) {
            for y in Swift.stride(from: 0, to: height, by: stride) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                    if a > 0.5 { // Skip transparent pixels
                        pixels.append(HSBColor(h: h, s: s, b: b))
                    }
                }
            }
        }
        
        guard !pixels.isEmpty else { return [HSBColor(h: 0, s: 0, b: 0.5)] }
        
        // Initialize centroids spread across hue spectrum
        var centroids: [HSBColor] = (0..<k).map { i in
            pixels[i * pixels.count / k]
        }
        
        // Iterate
        for _ in 0..<iterations {
            // Assign pixels to nearest centroid
            var clusters: [[HSBColor]] = Array(repeating: [], count: k)
            for pixel in pixels {
                var minDist: CGFloat = .greatestFiniteMagnitude
                var minIdx = 0
                for (i, centroid) in centroids.enumerated() {
                    let dist = pixel.distance(to: centroid)
                    if dist < minDist {
                        minDist = dist
                        minIdx = i
                    }
                }
                clusters[minIdx].append(pixel)
            }
            
            // Recompute centroids
            for i in 0..<k {
                guard !clusters[i].isEmpty else { continue }
                let avgH = clusters[i].map(\.h).reduce(0, +) / CGFloat(clusters[i].count)
                let avgS = clusters[i].map(\.s).reduce(0, +) / CGFloat(clusters[i].count)
                let avgB = clusters[i].map(\.b).reduce(0, +) / CGFloat(clusters[i].count)
                centroids[i] = HSBColor(h: avgH, s: avgS, b: avgB)
            }
        }
        
        // Sort by saturation × brightness (most visually impactful first)
        return centroids.sorted { ($0.s * $0.b) > ($1.s * $1.b) }
    }
    
    // ════════════════════════════════════════
    // MARK: - Palette Generation
    // ════════════════════════════════════════
    
    /// Generate a specific palette variant from base colors
    private static func generatePalette(from baseColors: [HSBColor], variant: PaletteVariant) async -> ColorPalette {
        guard baseColors.count >= 3 else { return .placeholder }
        
        let transformed: [HSBColor]
        
        switch variant {
        case .warm:
            // Push hues toward warm spectrum (0-60°, red-yellow)
            transformed = baseColors.map { color in
                let warmHue = (color.h * 0.3 + 0.05).truncatingRemainder(dividingBy: 1.0) // Shift toward red/orange
                return HSBColor(h: warmHue, s: min(1, color.s * 1.2), b: min(1, color.b * 1.1))
            }
            
        case .cool:
            // Push hues toward cool spectrum (180-270°, cyan-blue)
            transformed = baseColors.map { color in
                let coolHue = (color.h * 0.3 + 0.55).truncatingRemainder(dividingBy: 1.0) // Shift toward cyan/blue
                return HSBColor(h: coolHue, s: min(1, color.s * 1.1), b: min(1, color.b * 1.05))
            }
            
        case .vibrant:
            // Maximize saturation, boost brightness
            transformed = baseColors.map { color in
                HSBColor(h: color.h, s: min(1, color.s * 1.6 + 0.2), b: min(1, color.b * 1.2 + 0.1))
            }
            
        case .muted:
            // Desaturate heavily, darken for noir aesthetic
            transformed = baseColors.map { color in
                HSBColor(h: color.h, s: color.s * 0.25, b: color.b * 0.6)
            }
            
        case .complementary:
            // Shift dominant hue by 180°, keep others rotated
            transformed = baseColors.enumerated().map { (index, color) in
                let shift: CGFloat = index == 0 ? 0.5 : (CGFloat(index) * 0.15)
                let compHue = (color.h + shift).truncatingRemainder(dividingBy: 1.0)
                return HSBColor(h: compHue, s: color.s, b: color.b)
            }
        }
        
        return ColorPalette(
            dominant: transformed[0].toColor(),
            secondary: transformed[min(1, transformed.count - 1)].toColor(),
            accent: transformed[min(2, transformed.count - 1)].toColor(),
            background: HSBColor(h: transformed[0].h, s: transformed[0].s * 0.3, b: 0.08).toColor(),
            highlight: HSBColor(
                h: transformed[0].h,
                s: max(0.05, transformed[0].s * 0.2),
                b: min(1, transformed[0].b + 0.5)
            ).toColor()
        )
    }
}

// ═══════════════════════════════════════════════════
// MARK: - HSB Color Model (for clustering math)
// ═══════════════════════════════════════════════════

struct HSBColor {
    let h: CGFloat  // 0-1
    let s: CGFloat  // 0-1
    let b: CGFloat  // 0-1
    
    func toColor() -> Color {
        Color(hue: h, saturation: s, brightness: b)
    }
    
    func distance(to other: HSBColor) -> CGFloat {
        // Circular hue distance + euclidean S/B
        let dh = min(abs(h - other.h), 1 - abs(h - other.h)) * 2.0
        let ds = s - other.s
        let db = b - other.b
        return sqrt(dh * dh + ds * ds + db * db)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Quantum Palette Selector View
// ═══════════════════════════════════════════════════
// 5 circles showing palette previews. Tap or swipe to select.

struct QuantumPaletteSelectorView: View {
    @ObservedObject var engine: QuantumPaletteEngine
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(QuantumPaletteEngine.PaletteVariant.allCases.enumerated()), id: \.element) { index, variant in
                let palette = engine.palettes[variant] ?? .placeholder
                let isActive = engine.activeVariant == variant
                
                Button(action: { engine.selectPalette(at: index) }) {
                    ZStack {
                        // Palette preview — stacked color rings
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: palette.gradient + [palette.gradient.first ?? .clear],
                                    center: .center
                                )
                            )
                            .frame(width: isActive ? 20 : 14, height: isActive ? 20 : 14)
                        
                        // Active indicator
                        if isActive {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
                }
                .buttonStyle(.plain)
                .help(variant.label)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    if value.translation.width > 20 {
                        engine.nextPalette()
                    } else if value.translation.width < -20 {
                        engine.previousPalette()
                    }
                }
        )
    }
}
