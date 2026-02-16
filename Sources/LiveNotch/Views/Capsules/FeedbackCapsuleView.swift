import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🤖 Feedback Capsule — "Invisible Driver"
// ═══════════════════════════════════════════════════
// Ephemeral toast that appears in the notch periphery
// for agent confirmations: "Exported stems", "Normalized -14 LUFS"
// Auto-dismisses after 3 seconds. Works in ALL modes.

struct FeedbackCapsuleView: View {
    let message: String
    let icon: String
    let tint: Color
    
    @State private var isVisible = false
    @State private var progress: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(tint)
            
            Text(message)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.2), lineWidth: 0.5)
        )
        // Progress drain at bottom
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Capsule()
                    .fill(tint.opacity(0.4))
                    .frame(width: geo.size.width * progress, height: 1.5)
                    .animation(.linear(duration: 3.0), value: progress)
            }
            .frame(height: 1.5)
            .padding(.horizontal, 4)
            .offset(y: 2)
        }
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : -8)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isVisible = true
            }
            // Start progress drain
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                progress = 0
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 📡 Feedback Manager
// ═══════════════════════════════════════════════════

@MainActor
final class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    struct FeedbackItem: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
        let tint: Color
        let timestamp = Date()
    }
    
    @Published var activeFeedback: FeedbackItem?
    private var dismissTimer: Timer?
    
    private init() {}
    
    /// Show a feedback capsule that auto-dismisses after 3 seconds
    func show(_ message: String, icon: String = "checkmark.circle.fill", tint: Color = .green) {
        dismissTimer?.invalidate()
        
        withAnimation {
            activeFeedback = FeedbackItem(message: message, icon: icon, tint: tint)
        }
        
        HapticManager.shared.play(.message)
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(DS.Spring.snap) {
                    self?.activeFeedback = nil
                }
            }
        }
    }
    
    // ── Convenience Methods ──
    
    func exportComplete(_ format: String) {
        show("Exported \(format)", icon: "arrow.down.doc.fill", tint: .cyan)
    }
    
    func normalized(lufs: String) {
        show("Normalized to \(lufs)", icon: "waveform.badge.magnifyingglass", tint: .green)
    }
    
    func renamed(_ count: Int) {
        show("Renamed \(count) takes", icon: "pencil.line", tint: .orange)
    }
    
    func uploadComplete(_ filename: String) {
        show("\(filename) uploaded", icon: "icloud.and.arrow.up.fill", tint: .blue)
    }
}
