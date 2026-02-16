import SwiftUI

struct DaemonView: View {
    @ObservedObject var engine = DaemonEngine.shared
    @State private var blinkState = false
    @State private var lookOffset: CGSize = .zero
    
    // Eye properties
    let eyeSize: CGFloat = 8
    let eyeSpacing: CGFloat = 22
    
    // ═══════════════════════════════════════
    // MARK: - Timers
    // ═══════════════════════════════════════
    
    private let blinkTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    // PERF: 2.0s is plenty for eye direction — was 0.1s (10fps), pure waste
    private let lookTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: eyeSpacing) {
            // Left Eye
            daemonEye()
            // Right Eye
            daemonEye()
        }
        .onReceive(blinkTimer) { _ in
            if Int.random(in: 0...2) == 0 {
                blink()
            }
        }
        .onReceive(lookTimer) { _ in
            if engine.state == .watching || engine.state == .hunting {
                updateLookDirection()
            } else {
                lookOffset = .zero
            }
        }
    }
    
    private func daemonEye() -> some View {
        ZStack {
            // Glow
            Circle()
                .fill(engine.state == .sleeping ? Color.gray : Color.red)
                .frame(width: eyeSize * 2, height: eyeSize * 2)
                .blur(radius: 6)
                .opacity(engine.state == .sleeping ? 0.2 : 0.8)
            
            // Eye Ball
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: eyeSize)
                .scaleEffect(y: blinkState ? 0.1 : 1.0)
            
            // Pupil (if awake)
            if engine.state != .sleeping {
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeSize * 0.4, height: eyeSize * 0.4)
                    .offset(lookOffset)
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: lookOffset)
        .animation(DS.Spring.micro, value: blinkState)
    }
    
    
    private func blink() {
        blinkState = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            blinkState = false
        }
    }
    
    private func updateLookDirection() {
        // In a real app, this would get NSEvent.mouseLocation
        // For this demo, we can just oscillate slightly
        let time = Date().timeIntervalSince1970
        lookOffset = CGSize(
            width: cos(time * 2) * 2,
            height: sin(time * 3) * 1
        )
    }
}
