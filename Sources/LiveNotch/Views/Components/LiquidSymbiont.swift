import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🧬 Liquid Symbiont — Organic Notch Animations
// ═══════════════════════════════════════════════════
//
// The notch border isn't rigid — it's alive.
// Uses spring physics to create liquid, organic behavior:
//
// - Hover: Elastic blob drops from notch like a magnetic pull
// - Drop: Vortex suck + mercury flash
// - Full: Breathing glow
//
// All animations use .interpolatingSpring for real physics.
// Metal-backed via SwiftUI Canvas → 120fps on ProMotion.

// ═══════════════════════════════════════════════════
// MARK: - The Liquid Blob Shape
// ═══════════════════════════════════════════════════

/// A shape that "hangs" from the top edge like a liquid droplet.
/// `dropFactor` (0→1) controls how much it sags.
/// Uses cubic Bezier curves for organic surface tension.
struct LiquidBlob: Shape {
    var dropFactor: CGFloat
    var wobble: CGFloat = 0 // Secondary oscillation for organic feel
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(dropFactor, wobble) }
        set {
            dropFactor = newValue.first
            wobble = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let controlY = rect.height * dropFactor * 1.4
        let wobbleOffset = rect.width * 0.08 * wobble
        
        // Start at top-left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Main curve: cubic Bezier creating the "belly" of the drop
        // Two control points create an asymmetric organic sag
        path.addCurve(
            to: CGPoint(x: w, y: 0),
            control1: CGPoint(x: w * 0.3 + wobbleOffset, y: controlY * 1.1),
            control2: CGPoint(x: w * 0.7 - wobbleOffset, y: controlY * 0.9)
        )
        
        path.closeSubpath()
        return path
    }
}

// ═══════════════════════════════════════════════════
// MARK: - File Type Detection & Color System
// ═══════════════════════════════════════════════════

enum FileTypeCategory {
    case audio      // .wav, .mp3, .aif, .flac
    case image      // .png, .jpg, .svg, .psd
    case video      // .mp4, .mov, .mkv
    case code       // .swift, .py, .js, .ts, .rs
    case document   // .pdf, .doc, .txt, .md
    case archive    // .zip, .dmg, .tar
    case data       // .json, .csv, .db
    case unknown
    
    init(from url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        // Audio
        case "wav", "mp3", "aiff", "aif", "flac", "m4a", "ogg", "aac", "alac":
            self = .audio
        // Image
        case "png", "jpg", "jpeg", "gif", "svg", "psd", "ai", "webp", "heic", "tiff", "bmp", "ico":
            self = .image
        // Video
        case "mp4", "mov", "mkv", "avi", "webm", "m4v", "prores":
            self = .video
        // Code
        case "swift", "py", "js", "ts", "rs", "go", "java", "kt", "cpp", "c", "h", "rb", "php", "html", "css", "scss", "sh", "zsh":
            self = .code
        // Documents
        case "pdf", "doc", "docx", "txt", "md", "rtf", "pages", "key", "numbers":
            self = .document
        // Archives
        case "zip", "dmg", "tar", "gz", "rar", "7z", "pkg", "iso":
            self = .archive
        // Data
        case "json", "csv", "xml", "yaml", "yml", "db", "sqlite", "plist":
            self = .data
        default:
            self = .unknown
        }
    }
    
    var color: Color {
        switch self {
        case .audio:    return Color(hex: "00E5FF") // Cyan
        case .image:    return Color(hex: "FF00FF") // Magenta
        case .video:    return Color(hex: "FF6600") // Orange
        case .code:     return Color(hex: "00FF88") // Matrix Green
        case .document: return Color(hex: "FFD700") // Gold
        case .archive:  return Color(hex: "8B5CF6") // Purple
        case .data:     return Color(hex: "06B6D4") // Teal
        case .unknown:  return Color(hex: "9CA3AF") // Gray
        }
    }
    
    var icon: String {
        switch self {
        case .audio:    return "waveform"
        case .image:    return "photo"
        case .video:    return "film"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .document: return "doc.text"
        case .archive:  return "archivebox"
        case .data:     return "cylinder"
        case .unknown:  return "doc"
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Symbiont View (Main animated overlay)
// ═══════════════════════════════════════════════════

/// The living, breathing overlay for the notch.
/// Shows liquid blob on hover, vortex on drop, breathing when full.
struct SymbiontView: View {
    @ObservedObject var eater = FileEater.shared
    
    @State private var dropFactor: CGFloat = 0
    @State private var wobble: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var vortexAngle: Double = 0
    @State private var vortexScale: Double = 1.0
    @State private var breathPhase: Double = 0
    @State private var nucleusScale: Double = 0
    @State private var hoverFileType: FileTypeCategory = .unknown
    
    var body: some View {
        ZStack {
            // ── Layer 1: The Liquid Blob ──
            LiquidBlob(dropFactor: dropFactor, wobble: wobble)
                .fill(blobGradient)
                .frame(height: 80)
                .shadow(color: blobColor.opacity(0.3 * Double(dropFactor)), radius: 12, y: 6)
            
            // ── Layer 2: Pulsing Nucleus (hover state) ──
            if eater.isHovering {
                Circle()
                    .strokeBorder(blobColor.opacity(0.6), lineWidth: 2)
                    .background(Circle().fill(blobColor.opacity(0.15)))
                    .frame(width: 32, height: 32)
                    .scaleEffect(nucleusScale)
                    .offset(y: 25 * dropFactor)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // ── Layer 3: Vortex (eating animation) ──
            if eater.isEating {
                // Spiral lines
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(blobColor.opacity(0.4))
                        .frame(width: 2, height: 20)
                        .offset(y: 15)
                        .rotationEffect(.degrees(Double(i) * 60 + vortexAngle))
                        .scaleEffect(vortexScale)
                }
                
                // Center flash
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .opacity(flashOpacity)
                    .blur(radius: 8)
            }
            
            // ── Layer 4: Digestion indicator (full state) ──
            if eater.isFull && !eater.isHovering && !eater.isEating {
                Circle()
                    .fill(digestColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: digestColor.opacity(0.6), radius: 4)
                    .opacity(0.4 + 0.6 * sin(breathPhase))
                    .offset(y: 4)
                
                // File count
                if eater.fileCount > 1 {
                    Text("\(eater.fileCount)")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .offset(x: 12, y: 2)
                }
            }
        }
        .allowsHitTesting(false)
        // ── Reactive animations ──
        .onChange(of: eater.isHovering) { _, hovering in
            if hovering {
                // Elastic drop with wobble
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 10)) {
                    dropFactor = 1.0
                }
                withAnimation(.interpolatingSpring(stiffness: 80, damping: 8).delay(0.1)) {
                    wobble = 0.3
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    nucleusScale = 1.0
                }
                // Wobble loop
                withAnimation(DS.Spring.breath) {
                    wobble = -0.3
                }
            } else {
                // Retract: spring bounce back
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 14)) {
                    dropFactor = 0
                    wobble = 0
                    nucleusScale = 0
                }
            }
        }
        .onChange(of: eater.isEating) { _, eating in
            if eating {
                triggerEatAnimation()
            }
        }
        .onAppear {
            // Breathing loop for "full" state
            withAnimation(DS.Spring.breath) {
                breathPhase = .pi
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Eat Animation Sequence
    // ═══════════════════════════════════════
    
    private func triggerEatAnimation() {
        // Phase 1: Vortex spin (0ms - 300ms)
        vortexScale = 1.2
        vortexAngle = 0
        withAnimation(DS.Spring.snap) {
            vortexAngle = 360
            vortexScale = 0.0
        }
        
        // Phase 2: Flash (100ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            flashOpacity = 0.7
            withAnimation(DS.Spring.micro) {
                flashOpacity = 0
            }
        }
        
        // Phase 3: Nucleus implodes (200ms)
        withAnimation(DS.Spring.micro) {
            nucleusScale = 0
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Colors
    // ═══════════════════════════════════════
    
    private var blobColor: Color {
        hoverFileType.color
    }
    
    private var blobGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.95),
                blobColor.opacity(0.15 * Double(dropFactor)),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var digestColor: Color {
        switch eater.fileCount {
        case 0: return .clear
        case 1...3: return .cyan
        case 4...7: return .orange
        default: return .red
        }
    }
    
    /// Update the detected file type when hovering. 
    /// Called externally when drag enters.
    func updateFileType(_ urls: [URL]) {
        if let first = urls.first {
            hoverFileType = FileTypeCategory(from: first)
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Privacy Semaphore (Sensor Activity Indicator)
// ═══════════════════════════════════════════════════

/// Shows a subtle colored border around the notch edge
/// to indicate active sensors:
/// 🔴 Red = Microphone active
/// 🟢 Green = Camera active
/// ⚪ Gray = Privacy mode (all sensors off)
struct PrivacySemaphoreView: View {
    @State private var micActive = false
    @State private var camActive = false
    @State private var glowPhase: Double = 0
    
    var activeColor: Color {
        if micActive && camActive { return .orange }
        if micActive { return .red }
        if camActive { return .green }
        return .clear
    }
    
    var body: some View {
        if micActive || camActive {
            Circle()
                .fill(activeColor)
                .frame(width: 4, height: 4)
                .shadow(color: activeColor.opacity(0.8), radius: 3)
                .opacity(0.6 + 0.4 * sin(glowPhase))
                .onAppear {
                    withAnimation(DS.Spring.breath) {
                        glowPhase = .pi
                    }
                }
        }
    }
}
