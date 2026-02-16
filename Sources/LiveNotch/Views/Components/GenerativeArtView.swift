import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Generative Art — "Album Art Alucinógeno"
// ═══════════════════════════════════════════════════
// When no album artwork is available, generates a unique
// pseudo-cover in real-time using hash-seeded visuals.
// Seed = title + artist (hash) → deterministic but unique.
// NEVER show a placeholder — always look premium.

struct GenerativeArtView: View {
    let title: String
    let artist: String
    let size: CGFloat
    
    // Deterministic seed from track info
    private var seed: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(artist)
        return abs(hasher.finalize())
    }
    
    // Derived palette (3 colors from seed)
    private var palette: [Color] {
        let hue1 = Double(seed % 360) / 360.0
        let hue2 = Double((seed / 360) % 360) / 360.0
        let hue3 = Double((seed / 129600) % 360) / 360.0
        
        return [
            Color(hue: hue1, saturation: 0.6, brightness: 0.5),
            Color(hue: hue2, saturation: 0.5, brightness: 0.3),
            Color(hue: hue3, saturation: 0.4, brightness: 0.7)
        ]
    }
    
    // Shape parameters from seed
    private var shapeCount: Int { 2 + (seed % 4) }
    private var rotation: Double { Double(seed % 180) }
    private var scale: CGFloat { 0.5 + CGFloat(seed % 50) / 100.0 }
    
    var body: some View {
        Canvas { context, canvasSize in
            drawBackground(context: context, size: canvasSize)
            drawShapes(context: context, size: canvasSize)
            drawNoise(context: context, size: canvasSize)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let bgGradient = Gradient(colors: [
            palette[0].opacity(0.8),
            palette[1].opacity(0.6),
            Color.black
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                bgGradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
    }
    
    private func drawShapes(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        for i in 0..<shapeCount {
            let angle = (Double(i) / Double(shapeCount)) * .pi * 2 + rotation * .pi / 180
            let shapeCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * 0.3,
                y: center.y + CGFloat(sin(angle)) * radius * 0.3
            )
            let shapeRadius = radius * (0.2 + CGFloat(i) * 0.1)
            
            var path = Path()
            if i % 3 == 0 {
                path.addEllipse(in: CGRect(
                    x: shapeCenter.x - shapeRadius / 2,
                    y: shapeCenter.y - shapeRadius / 2,
                    width: shapeRadius,
                    height: shapeRadius
                ))
            } else if i % 3 == 1 {
                path.addRoundedRect(
                    in: CGRect(
                        x: shapeCenter.x - shapeRadius / 2,
                        y: shapeCenter.y - shapeRadius / 2,
                        width: shapeRadius,
                        height: shapeRadius * 0.7
                    ),
                    cornerSize: CGSize(width: 6, height: 6)
                )
            } else {
                let triRadius = shapeRadius * 0.4
                path.move(to: CGPoint(x: shapeCenter.x, y: shapeCenter.y - triRadius))
                path.addLine(to: CGPoint(x: shapeCenter.x - triRadius, y: shapeCenter.y + triRadius))
                path.addLine(to: CGPoint(x: shapeCenter.x + triRadius, y: shapeCenter.y + triRadius))
                path.closeSubpath()
            }
            
            let colorIndex = i % palette.count
            context.fill(path, with: .color(palette[colorIndex].opacity(0.3)))
            context.stroke(path, with: .color(palette[colorIndex].opacity(0.15)), lineWidth: 0.5)
        }
    }
    
    private func drawNoise(context: GraphicsContext, size: CGSize) {
        let noiseCount = 80
        for j in 0..<noiseCount {
            let nx = CGFloat((seed + j * 7) % Int(size.width))
            let ny = CGFloat((seed + j * 13) % Int(size.height))
            let noiseDot = Path(ellipseIn: CGRect(x: nx, y: ny, width: 1, height: 1))
            context.fill(noiseDot, with: .color(.white.opacity(0.03)))
        }
    }
}
