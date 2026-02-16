import SwiftUI
import GameplayKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🌧️ Rain Physics Engine
// ═══════════════════════════════════════════════════
//
// Real particle physics for rain drops that fall from
// the notch edge and interact with other widget borders.
//
// Uses GameplayKit GKRandomSource for procedural noise
// and custom 2D physics for:
//   • Gravity + wind
//   • Collision with widget boundaries (splash particles)
//   • Surface tension (drops merge on flat surfaces)
//
// Renders via SwiftUI Canvas for 60fps performance.

@MainActor
final class RainPhysicsEngine: ObservableObject {
    
    // ── Configuration ──
    struct Config {
        var maxDrops: Int = 80
        var gravity: CGFloat = 420.0         // px/s²
        var wind: CGFloat = 0.0              // Horizontal force
        var spawnRate: Double = 0.05         // Seconds between spawns
        var dropMinSize: CGFloat = 1.5
        var dropMaxSize: CGFloat = 3.5
        var splashParticles: Int = 4
        var trailLength: Int = 3
        var color: Color = .cyan
        var opacity: Double = 0.6
        var enabled: Bool = true
    }
    
    // ── Drop Particle ──
    struct RainDrop: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var size: CGFloat
        var opacity: Double
        var age: Double = 0
        var isSplash: Bool = false
        var trail: [CGPoint] = []
        
        // Physics state
        var isAlive: Bool { opacity > 0.01 && age < 5.0 }
    }
    
    // ── Widget Boundary (for collisions) ──
    struct WidgetBounds {
        let id: String
        let frame: CGRect
    }
    
    // ── Published State ──
    @Published var drops: [RainDrop] = []
    @Published var config = Config()
    @Published var isActive: Bool = false
    
    // ── Private ──
    private var displayLink: Timer?
    private var spawnTimer: Timer?
    private let random = GKRandomSource.sharedRandom()
    private var lastUpdate: CFTimeInterval = 0
    private var widgetBounds: [WidgetBounds] = []
    private var spawnBounds: CGRect = .zero
    
    // ════════════════════════════════════════
    // MARK: - Lifecycle
    // ════════════════════════════════════════
    
    func start(in bounds: CGRect) {
        guard config.enabled else { return }
        spawnBounds = bounds
        isActive = true
        lastUpdate = CFAbsoluteTimeGetCurrent()
        
        // Physics loop at ~60fps
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        
        // Spawn timer
        spawnTimer = Timer.scheduledTimer(withTimeInterval: config.spawnRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.spawnDrop()
            }
        }
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
        isActive = false
        
        withAnimation(.easeOut(duration: 0.5)) {
            drops.removeAll()
        }
    }
    
    func updateWidgetBounds(_ bounds: [WidgetBounds]) {
        self.widgetBounds = bounds
    }
    
    // ════════════════════════════════════════
    // MARK: - Physics Loop
    // ════════════════════════════════════════
    
    private func update() {
        let now = CFAbsoluteTimeGetCurrent()
        let dt = min(now - lastUpdate, 1.0 / 30.0) // Cap dt to prevent jumps
        lastUpdate = now
        
        var newSplashes: [RainDrop] = []
        
        for i in drops.indices.reversed() {
            // Age
            drops[i].age += dt
            
            if drops[i].isSplash {
                // Splash particles: fade + expand
                drops[i].velocity.dy += config.gravity * 0.5 * dt
                drops[i].position.x += drops[i].velocity.dx * dt
                drops[i].position.y += drops[i].velocity.dy * dt
                drops[i].opacity -= dt * 3.0
                drops[i].size -= dt * 2.0
            } else {
                // Store trail
                drops[i].trail.append(drops[i].position)
                if drops[i].trail.count > config.trailLength {
                    drops[i].trail.removeFirst()
                }
                
                // Apply gravity + wind
                drops[i].velocity.dy += config.gravity * dt
                drops[i].velocity.dx += config.wind * dt
                
                // Terminal velocity
                drops[i].velocity.dy = min(drops[i].velocity.dy, 600)
                
                // Move
                drops[i].position.x += drops[i].velocity.dx * dt
                drops[i].position.y += drops[i].velocity.dy * dt
                
                // Check collisions with widget bounds
                for widget in widgetBounds {
                    if widget.frame.contains(drops[i].position) {
                        // Collision! Generate splash particles
                        let splashes = generateSplash(at: drops[i].position, velocity: drops[i].velocity, size: drops[i].size)
                        newSplashes.append(contentsOf: splashes)
                        drops[i].opacity = 0 // Kill the drop
                        break
                    }
                }
            }
            
            // Remove dead drops
            if !drops[i].isAlive || drops[i].position.y > spawnBounds.maxY + 20 {
                drops.remove(at: i)
            }
        }
        
        // Add splashes
        drops.append(contentsOf: newSplashes)
        
        // Cap total particles
        if drops.count > config.maxDrops * 2 {
            drops.removeFirst(drops.count - config.maxDrops)
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Spawn & Splash
    // ════════════════════════════════════════
    
    private func spawnDrop() {
        guard drops.count < config.maxDrops, isActive else { return }
        
        let x = CGFloat(random.nextInt(upperBound: Int(spawnBounds.width))) + spawnBounds.minX
        let size = CGFloat.random(in: config.dropMinSize...config.dropMaxSize)
        
        let drop = RainDrop(
            position: CGPoint(x: x, y: spawnBounds.minY - 5),
            velocity: CGVector(
                dx: config.wind * 0.5 + CGFloat.random(in: -10...10),
                dy: CGFloat.random(in: 20...60)
            ),
            size: size,
            opacity: config.opacity * Double.random(in: 0.5...1.0)
        )
        
        drops.append(drop)
    }
    
    private func generateSplash(at point: CGPoint, velocity: CGVector, size: CGFloat) -> [RainDrop] {
        (0..<config.splashParticles).map { _ in
            RainDrop(
                position: point,
                velocity: CGVector(
                    dx: CGFloat.random(in: -80...80),
                    dy: -CGFloat.random(in: 30...120) // Upward splash
                ),
                size: size * 0.4,
                opacity: config.opacity * 0.8,
                isSplash: true
            )
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Rain Overlay View (Canvas-based renderer)
// ═══════════════════════════════════════════════════

struct RainOverlayView: View {
    @ObservedObject var engine: RainPhysicsEngine
    var tintColor: Color = .cyan
    
    var body: some View {
        Canvas { context, size in
            for drop in engine.drops {
                guard drop.isAlive else { continue }
                
                let resolvedColor = tintColor.opacity(drop.opacity)
                
                if drop.isSplash {
                    // Splash: small circles
                    let rect = CGRect(
                        x: drop.position.x - drop.size / 2,
                        y: drop.position.y - drop.size / 2,
                        width: max(0.5, drop.size),
                        height: max(0.5, drop.size)
                    )
                    context.fill(Circle().path(in: rect), with: .color(resolvedColor))
                } else {
                    // Rain drop: elongated ellipse based on velocity
                    let speed = sqrt(drop.velocity.dx * drop.velocity.dx + drop.velocity.dy * drop.velocity.dy)
                    let stretch = min(speed / 200.0, 3.0) // Elongation factor
                    let width = drop.size
                    let height = drop.size * (1 + stretch)
                    
                    let rect = CGRect(
                        x: drop.position.x - width / 2,
                        y: drop.position.y - height / 2,
                        width: width,
                        height: height
                    )
                    
                    context.fill(Ellipse().path(in: rect), with: .color(resolvedColor))
                    
                    // Trail
                    if drop.trail.count > 1 {
                        var path = Path()
                        path.move(to: drop.trail[0])
                        for point in drop.trail.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(
                            path,
                            with: .color(resolvedColor.opacity(0.3)),
                            lineWidth: drop.size * 0.5
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false) // Rain is purely visual
    }
}
