import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🌌 SwarmParticleView — Living Dots in the Notch
// ═══════════════════════════════════════════════════
// Renders each agent as a glowing particle inside the notch
// when collapsed. Working agents pulse, idle ones drift.
// Collaboration lines connect related agents.
//
// This Canvas runs at ~30fps via TimelineView and renders
// on top of the LiquidNotchView glass.

@available(macOS 14.0, *)
struct SwarmParticleView: View {
    @ObservedObject var swarm: SwarmEngine
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let scaleX = size.width / 180.0  // Normalize to notch-space
                let scaleY = size.height / 34.0
                
                // ── 1. Connection Lines ──
                for (a, b) in swarm.connections {
                    guard a.isAlive && b.isAlive else { continue }
                    
                    let pA = scaled(a.position, scaleX: scaleX, scaleY: scaleY)
                    let pB = scaled(b.position, scaleX: scaleX, scaleY: scaleY)
                    
                    var path = Path()
                    path.move(to: pA)
                    // Bezier curve for organic feel
                    let mid = CGPoint(
                        x: (pA.x + pB.x) / 2 + CGFloat.random(in: -2...2),
                        y: (pA.y + pB.y) / 2 + CGFloat.random(in: -1...1)
                    )
                    path.addQuadCurve(to: pB, control: mid)
                    
                    // Color = blend of both agents
                    let lineColor = a.role.color.opacity(0.15)
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
                
                // ── 2. Agent Particles ──
                for agent in swarm.livingAgents {
                    let pos = scaled(agent.position, scaleX: scaleX, scaleY: scaleY)
                    let baseSize: CGFloat = agent.isWorking ? 3.5 : 2.5
                    let size = baseSize * agent.particleScale
                    
                    // Glow halo
                    let glowRect = CGRect(
                        x: pos.x - size * 2,
                        y: pos.y - size * 2,
                        width: size * 4,
                        height: size * 4
                    )
                    context.opacity = agent.glowIntensity * 0.3
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(agent.role.color)
                    )
                    
                    // Core dot
                    let coreRect = CGRect(
                        x: pos.x - size / 2,
                        y: pos.y - size / 2,
                        width: size,
                        height: size
                    )
                    context.opacity = agent.glowIntensity
                    context.fill(
                        Path(ellipseIn: coreRect),
                        with: .color(agent.role.color)
                    )
                }
                
                // ── 3. Transfer Particles ──
                for agent in swarm.agents {
                    if case .transferring(let targetID) = agent.status,
                       let target = swarm.livingAgents.first(where: { $0.id == targetID }) {
                        // Draw a moving dot from agent → target
                        let progress = agent.progress
                        let from = scaled(agent.position, scaleX: scaleX, scaleY: scaleY)
                        let to = scaled(target.position, scaleX: scaleX, scaleY: scaleY)
                        let transferPos = CGPoint(
                            x: from.x + (to.x - from.x) * progress,
                            y: from.y + (to.y - from.y) * progress
                        )
                        let dot = CGRect(x: transferPos.x - 1.5, y: transferPos.y - 1.5, width: 3, height: 3)
                        context.opacity = 0.9
                        context.fill(Path(ellipseIn: dot), with: .color(.white))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func scaled(_ point: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scaleX, y: point.y * scaleY)
    }
}
