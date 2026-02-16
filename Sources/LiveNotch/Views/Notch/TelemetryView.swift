import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🌌 TelemetryView — Enhanced Particle Absorption
// Merged: OnyxNotch Canvas particles + LiveNotch gravity well
// ═══════════════════════════════════════════════════

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    var scale: CGFloat
    var speed: CGFloat
    var hue: Double        // OnyxNotch: per-particle color variation
    var wobble: CGFloat    // Lateral sine movement
    var wobbleSpeed: CGFloat
}

struct TelemetryView: View {
    @State private var particles: [Particle] = []
    @State private var lastSpawnTime: Date = .distantPast
    @State private var frameCount: Int = 0
    @ObservedObject var stateMachine = NotchStateMachine.shared
    
    let geometry: NotchGeometry
    
    /// Override glow color (e.g. from FileTypeColors)
    var glowColor: Color?
    
    /// Spawn rate adapts to state
    private var spawnInterval: TimeInterval {
        switch stateMachine.state {
        case .expanded:  return 1.0 / 40.0  // Dense particles when expanded
        case .peek:      return 1.0 / 25.0
        case .sending:   return 1.0 / 60.0  // High speed transfer effect
        case .delivery:  return 1.0 / 20.0  // Slowing down
        case .audioWake: return 1.0 / 15.0  // Subtle ambient
        case .idle:      return 1.0 / 8.0   // Sparse idle shimmer
        }
    }
    
    private var maxParticles: Int {
        switch stateMachine.state {
        case .expanded:  return 120
        case .peek:      return 80
        case .sending:   return 150
        case .delivery:  return 60
        case .audioWake: return 40
        case .idle:      return 15
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x - particle.scale,
                        y: particle.y - particle.scale,
                        width: particle.scale * 2,
                        height: particle.scale * 2
                    )
                    
                    // Core dot — hue-varied color (OnyxNotch style)
                    let color = Color(hue: particle.hue, saturation: 0.8, brightness: 0.95)
                    
                    // Glow halo (OnyxNotch: outer glow ring)
                    let glowRect = rect.insetBy(dx: -3, dy: -3)
                    var glowCtx = context
                    glowCtx.opacity = particle.opacity * 0.25
                    glowCtx.addFilter(.blur(radius: 3))
                    glowCtx.fill(Path(ellipseIn: glowRect), with: .color(color))
                    
                    // Core particle
                    var coreCtx = context
                    coreCtx.opacity = particle.opacity
                    coreCtx.addFilter(.blur(radius: 0.5))
                    coreCtx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                updateParticles()
                frameCount += 1
                
                if newDate.timeIntervalSince(lastSpawnTime) >= spawnInterval {
                    lastSpawnTime = newDate
                    spawnParticle()
                }
            }
        }
        .frame(width: geometry.notchWidth + 40, height: geometry.notchHeight + 50)
        .allowsHitTesting(false)
    }
    
    private func spawnParticle() {
        guard particles.count < maxParticles else { return }
        let spread = geometry.notchWidth + 40
        
        let newParticle = Particle(
            x: CGFloat.random(in: 0...spread) - 20,
            y: geometry.notchHeight + CGFloat.random(in: 10...40),
            opacity: Double.random(in: 0.4...0.9),
            scale: CGFloat.random(in: 0.5...2.0),
            speed: CGFloat.random(in: 0.4...1.5),
            hue: Double.random(in: 0.5...0.65),  // Cyan-teal range by default
            wobble: CGFloat.random(in: 0...(.pi * 2)),
            wobbleSpeed: CGFloat.random(in: 0.05...0.15)
        )
        
        particles.append(newParticle)
    }

    private func updateParticles() {
        let centerX = (geometry.notchWidth + 40) / 2
        let eventHorizonY = geometry.notchHeight * 0.15
        
        for i in 0..<particles.count {
            // Move UP towards the event horizon
            particles[i].y -= particles[i].speed
            
            // Lateral wobble (OnyxNotch: sine wave drift)
            particles[i].wobble += particles[i].wobbleSpeed
            particles[i].x += sin(particles[i].wobble) * 0.3
            
            // Stronger gravity well near the center (absorption effect)
            let distX = centerX - particles[i].x
            let distY = eventHorizonY - particles[i].y
            let proximity = max(abs(distY) / geometry.notchHeight, 0.1)
            let pullStrength = 0.03 / proximity  // Stronger pull when closer
            particles[i].x += distX * min(pullStrength, 0.15)
            
            // Fade + shrink as absorbed
            if particles[i].y < geometry.notchHeight * 0.3 {
                particles[i].opacity -= 0.04
                particles[i].scale *= 0.97  // Shrink into the event horizon
            } else {
                particles[i].opacity -= 0.003
            }
        }
        
        // Clean dead particles
        particles.removeAll { $0.opacity <= 0 || $0.y < 0 || $0.scale < 0.1 }
    }
}
