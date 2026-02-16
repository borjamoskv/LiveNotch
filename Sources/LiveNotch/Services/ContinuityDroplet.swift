import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🧵 Continuity Droplet — "El Hilo de Ariadna"
// ═══════════════════════════════════════════════════
// Monitors NSPasteboard for Universal Clipboard (Handoff)
// changes. When content arrives from another device:
// 1. Notch edge flashes imperceptibly
// 2. A glass droplet "drips" from the hardware
// 3. Droplet is draggable to desktop (NSItemProvider)
// 4. Content is ready for Cmd+V anywhere

@MainActor
final class ContinuityDroplet: ObservableObject {
    static let shared = ContinuityDroplet()
    
    @Published var hasDroplet: Bool = false
    @Published var dropletType: DropletType = .text
    @Published var dropletPreview: String = ""
    @Published var animationPhase: CGFloat = 0.0
    
    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    
    enum DropletType {
        case text
        case image
        case url
        case file
        
        var icon: String {
            switch self {
            case .text: return "doc.text.fill"
            case .image: return "photo.fill"
            case .url: return "link"
            case .file: return "doc.fill"
            }
        }
        
        var tint: Color {
            switch self {
            case .text: return .white
            case .image: return .cyan
            case .url: return .blue
            case .file: return .orange
            }
        }
    }
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Monitoring
    // ════════════════════════════════════════
    
    func startMonitoring() {
        // Poll every 500ms (NSPasteboard has no notification API)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkPasteboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // Detect content type
        let types = pb.types ?? []
        
        if types.contains(.png) || types.contains(.tiff) {
            dropletType = .image
            dropletPreview = "Image from clipboard"
        } else if types.contains(.URL) || types.contains(.string),
                  let str = pb.string(forType: .string),
                  str.hasPrefix("http") {
            dropletType = .url
            dropletPreview = String(str.prefix(40))
        } else if types.contains(.fileURL) {
            dropletType = .file
            dropletPreview = "File from clipboard"
        } else if types.contains(.string) {
            dropletType = .text
            let str = pb.string(forType: .string) ?? ""
            dropletPreview = String(str.prefix(30))
        } else {
            return  // Unknown type, ignore
        }
        
        // Animate droplet appearance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            hasDroplet = true
            animationPhase = 1.0
        }
        
        HapticManager.shared.play(.message)
        
        // Auto-dismiss after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            withAnimation(DS.Spring.soft) {
                self?.hasDroplet = false
                self?.animationPhase = 0.0
            }
        }
    }
    
    /// Manually dismiss the droplet
    func dismiss() {
        withAnimation(DS.Spring.snap) {
            hasDroplet = false
            animationPhase = 0.0
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 💧 Droplet View
// ═══════════════════════════════════════════════════

struct ContinuityDropletView: View {
    @ObservedObject var droplet = ContinuityDroplet.shared
    
    var body: some View {
        if droplet.hasDroplet {
            VStack(spacing: 2) {
                // Glass droplet
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .stroke(droplet.dropletType.tint.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: droplet.dropletType.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(droplet.dropletType.tint)
                }
                .shadow(color: droplet.dropletType.tint.opacity(0.3), radius: 6)
                .scaleEffect(droplet.animationPhase)
                // Trembling effect
                .offset(
                    x: droplet.hasDroplet ? CGFloat.random(in: -0.5...0.5) : 0,
                    y: droplet.hasDroplet ? CGFloat.random(in: -0.3...0.3) : 0
                )
                .animation(
                    DS.Spring.breath,
                    value: droplet.hasDroplet
                )
                
                // Preview text
                Text(droplet.dropletPreview)
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .frame(maxWidth: 60)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .scale(scale: 0.5).combined(with: .opacity)
            ))
            .onTapGesture {
                droplet.dismiss()
                HapticManager.shared.play(.button)
            }
        }
    }
}
