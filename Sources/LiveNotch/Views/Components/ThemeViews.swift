import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - ⚡ Glitch Event Effect — "Glitch Mercy"
// ═══════════════════════════════════════════════════
// Glitch ONLY as event (notification, export done).
// Never permanent. If constant, it becomes noise.
// Each trigger = 300ms burst of controlled chaos, then silence.

struct GlitchEventOverlay: View {
    @Binding var isActive: Bool
    var intensity: CGFloat = 1.0
    
    @State private var sliceOffsets: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var rgbShift: CGFloat = 0
    @State private var scanlinePos: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isActive {
                    // RGB chromatic aberration
                    Color.red.opacity(0.08 * Double(intensity))
                        .offset(x: rgbShift * 2)
                        .blendMode(.screen)
                    
                    Color.cyan.opacity(0.06 * Double(intensity))
                        .offset(x: -rgbShift * 1.5)
                        .blendMode(.screen)
                    
                    // Horizontal scan line
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .offset(y: scanlinePos * geo.size.height - geo.size.height / 2)
                    
                    // Slice displacement (horizontal shifts)
                    ForEach(0..<sliceOffsets.count, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(0.02))
                            .frame(height: geo.size.height / CGFloat(sliceOffsets.count))
                            .offset(x: sliceOffsets[i], y: CGFloat(i) * geo.size.height / CGFloat(sliceOffsets.count) - geo.size.height / 2)
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: isActive) { _, active in
            if active { triggerGlitch() }
        }
    }
    
    private func triggerGlitch() {
        // Phase 1: Chaos burst (0-150ms)
        withAnimation(DS.Spring.micro) {
            rgbShift = CGFloat.random(in: 2...5) * intensity
            sliceOffsets = sliceOffsets.map { _ in CGFloat.random(in: -8...8) * intensity }
            scanlinePos = CGFloat.random(in: 0...1)
        }
        
        // Phase 2: Settle (150-250ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(DS.Spring.micro) {
                rgbShift = CGFloat.random(in: 0.5...2) * intensity
                sliceOffsets = sliceOffsets.map { _ in CGFloat.random(in: -2...2) }
            }
        }
        
        // Phase 3: Clean exit (250-300ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(DS.Spring.micro) {
                rgbShift = 0
                sliceOffsets = Array(repeating: 0, count: 5)
                scanlinePos = 0
            }
        }
        
        // Auto-deactivate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isActive = false
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🏔️ Lore Totem — Sigil + Chapter UI
// ═══════════════════════════════════════════════════

struct LoreTotemView: View {
    var projectIcon: String = "shield.lefthalf.filled"
    var chapters: [TotemChapter]
    var isRevealed: Bool = false
    var accentColor: Color = Color(red: 0.7, green: 0.5, blue: 1.0)
    
    struct TotemChapter: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Central sigil (always visible)
            Image(systemName: projectIcon)
                .font(.system(size: 14, weight: .thin))
                .foregroundColor(accentColor.opacity(isRevealed ? 0.9 : 0.3))
                .scaleEffect(isRevealed ? 1.1 : 1.0)
                .animation(DS.Spring.island, value: isRevealed)
            
            // Chapters (revealed on hover)
            if isRevealed {
                VStack(spacing: 2) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button(action: chapter.action) {
                            HStack(spacing: 6) {
                                Image(systemName: chapter.icon)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(accentColor.opacity(0.6))
                                    .frame(width: 12)
                                
                                Text(chapter.title)
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.3).delay(Double(index) * 0.05), value: isRevealed)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}
