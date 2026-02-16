import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🔥 Faro Alert View — Server-Push Visual Renderer
// ═══════════════════════════════════════════════════
//
// Renders alerts pushed from the Laravel backend.
// These can be: crypto price changes, NFT sales, custom alerts.
//
// The Mac does ZERO processing. Laravel does the thinking.
// This view just renders beautifully.
//
// Design: Slides down from the Notch with a colored glow,
// shows icon + message, then retracts. Like a lighthouse beam.

struct FaroAlertView: View {
    let alert: FaroAlert
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var glowIntensity: Double = 0
    @State private var textOpacity: Double = 0
    
    var alertColor: Color {
        Color(hex: alert.color)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: alert.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(alertColor)
                .shadow(color: alertColor.opacity(0.8), radius: 4)
            
            // Message
            Text(alert.message)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
                .opacity(textOpacity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            ZStack {
                // Base glass
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                // Colored glow overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(alertColor.opacity(0.15 * glowIntensity))
                
                // Border pulse
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        alertColor.opacity(0.6 * glowIntensity),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: alertColor.opacity(0.3 * glowIntensity), radius: 12, y: 4)
        .scaleEffect(isVisible ? 1.0 : 0.7)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : -10)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            withAnimation(DS.Spring.bounce) {
                textOpacity = 1.0
            }
            
            // Glow pulse loop
            startGlowPulse()
            
            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(alert.duration)) {
                withAnimation(DS.Spring.soft) {
                    isVisible = false
                    glowIntensity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onDismiss()
                }
            }
        }
    }
    
    private func startGlowPulse() {
        let baseIntensity: Double
        switch alert.intensity {
        case "high": baseIntensity = 1.0
        case "medium": baseIntensity = 0.7
        default: baseIntensity = 0.4
        }
        
        withAnimation(DS.Spring.breath) {
            glowIntensity = baseIntensity
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Faro Alert Model
// ═══════════════════════════════════════════════════

struct FaroAlert: Identifiable {
    let id = UUID()
    let color: String      // Hex color e.g. "#FFD700"
    let message: String
    let icon: String       // SF Symbol
    let duration: Int      // seconds
    let intensity: String  // "low", "medium", "high"
}

// ═══════════════════════════════════════════════════
// MARK: - Faro Alert Manager (receives from NotificationCenter)
// ═══════════════════════════════════════════════════

@MainActor
final class FaroAlertManager: ObservableObject {
    static let shared = FaroAlertManager()
    
    @Published var currentAlert: FaroAlert? = nil
    private var alertQueue: [FaroAlert] = []
    
    private init() {
        // Listen for relay faro alerts
        NotificationCenter.default.addObserver(
            forName: .relayFaroAlert,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.object as? [String: Any] else { return }
            
            let alert = FaroAlert(
                color: info["color"] as? String ?? "#FFFFFF",
                message: info["message"] as? String ?? "",
                icon: info["icon"] as? String ?? "bell.fill",
                duration: info["duration"] as? Int ?? 5,
                intensity: info["intensity"] as? String ?? "medium"
            )
            
            Task { @MainActor in
                self?.enqueue(alert)
            }
        }
    }
    
    func enqueue(_ alert: FaroAlert) {
        if currentAlert == nil {
            currentAlert = alert
        } else {
            alertQueue.append(alert)
        }
    }
    
    func dismiss() {
        currentAlert = nil
        // Show next in queue if any
        if !alertQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.currentAlert = self?.alertQueue.removeFirst()
            }
        }
    }
}

