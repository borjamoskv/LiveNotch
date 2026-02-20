import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🪽 Wing Views (NSTitlebarAccessoryViewController content)
// ═══════════════════════════════════════════════════
// Estas vistas viven en las wings de la titlebar.
// macOS las coloca automáticamente en las zonas auxiliares
// a izq/der del notch. NUNCA invaden el hueco.
//
// Son el cockpit principal. No widgets inútiles.

// ─────────────────────────────────────────
// MARK: Leading Wing (Contexto)
// ─────────────────────────────────────────
// Muestra: perfil de app activa + proyecto/doc/track activo

struct LeadingWingView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nervous = NervousSystem.shared
    @State private var breathPhase = false
    @State private var tapFlash = false
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            if viewModel.isPlaying {
                // 🎵 Music mode: Album art with waveform overlaid inside
                VStack(spacing: 2) {
                    ZStack {
                        if let art = viewModel.albumArtImage {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: DS.Layout.wingAlbum, height: DS.Layout.wingAlbum)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                        .fill(.black.opacity(0.35))
                                )
                                .shadow(color: viewModel.songChangeAlert ? viewModel.albumColor.opacity(0.5) : .clear, radius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(DS.Colors.textInvisible)
                                .frame(width: DS.Layout.wingAlbum, height: DS.Layout.wingAlbum)
                        }
                        // Waveform inside the album art
                        WaveformView(color: .white, playing: true, bars: 3, style: .mini)
                            .frame(width: DS.Layout.waveW, height: DS.Layout.waveH)
                    }
                    .scaleEffect(viewModel.songChangeAlert ? 1.15 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.songChangeAlert)
                    
                    // Mini progress bar below album art
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.albumColor.opacity(0.7), viewModel.albumColor.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, DS.Layout.wingAlbum * viewModel.trackProgress), height: 1.5)
                        .frame(width: DS.Layout.wingAlbum, alignment: .leading)
                        .shadow(color: viewModel.albumColor.opacity(0.4), radius: 2)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                // 🦎 Chameleon mode: Active app icon
                ZStack {
                    if let appIcon = nervous.activeAppIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: DS.Layout.wingIcon, height: DS.Layout.wingIcon)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
                            .shadow(color: nervous.activeAppColor.opacity(breathPhase ? 0.5 : 0.12), radius: 5)
                            .shadow(color: .black.opacity(0.6), radius: 1, y: 1) // Emboss depth
                    } else {
                        // Fallback: SF Symbol
                        Image(systemName: "macwindow")
                            .font(.system(size: DS.Icons.small, weight: .medium))
                            .foregroundStyle(nervous.activeAppColor.opacity(breathPhase ? 0.7 : 0.4))
                    }
                }
                .animation(DS.Spring.breath, value: breathPhase)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                // 🧠 Ghost count badge — peripheral CORTEX awareness
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.cortex.ghostCount > 0 {
                        Text("\(viewModel.cortex.ghostCount)")
                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 2.5)
                            .padding(.vertical, 0.5)
                            .background(
                                Capsule().fill(
                                    viewModel.cortex.ghostCount > 5
                                        ? Color.red.opacity(0.9)
                                        : Color.purple.opacity(0.8)
                                )
                            )
                            .offset(x: 5, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isPlaying)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.songChangeAlert)
        .animation(DS.Spring.soft, value: nervous.activeAppName)
        .scaleEffect(tapFlash ? 0.97 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if viewModel.isPlaying {
                viewModel.openMusicApp()
                HapticManager.shared.play(.success)
            }
        }
        .onTapGesture(count: 1) {
            HapticManager.shared.play(.toggle)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.isExpanded.toggle()
            }
        }
        .onAppear {
            breathPhase = true
        }
        .animation(DS.Spring.island, value: viewModel.currentTrack)
    }
}

struct NotchWingShape: Shape {
    var isLeft: Bool
    var bottomRadius: CGFloat = 14
    var topRadius: CGFloat = 0 // Used for Floating Island mode (no physical notch)
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(bottomRadius, min(w, h))
        
        if isLeft {
            // LEFT WING — Inner edge is RIGHT (x=w), Outer edge is LEFT (x=0)
            // Inner edge: STRAIGHT VERTICAL (hidden under notch hardware)
            // Outer bottom corner: ROUNDED
            
            path.move(to: CGPoint(x: w, y: 0))        // Top-Right (Inner, flush)
            
            if topRadius > 0 {
                path.addLine(to: CGPoint(x: topRadius, y: 0))
                path.addArc(
                    center: CGPoint(x: topRadius, y: topRadius),
                    radius: topRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(180),
                    clockwise: true
                )
            } else {
                path.addLine(to: CGPoint(x: 0, y: 0))      // Top-Left (Outer)
            }
            
            path.addLine(to: CGPoint(x: 0, y: h - r))  // Down outer edge
            
            // Outer bottom-left corner (rounded, visible)
            path.addArc(
                center: CGPoint(x: r, y: h - r),
                radius: r,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            
            path.addLine(to: CGPoint(x: w, y: h))      // Bottom-Right (Inner)
            path.addLine(to: CGPoint(x: w, y: 0))      // Up inner edge (STRAIGHT!)
            path.closeSubpath()
            
        } else {
            // RIGHT WING — Inner edge is LEFT (x=0), Outer edge is RIGHT (x=w)
            
            path.move(to: CGPoint(x: 0, y: 0))         // Top-Left (Inner, flush)
            
            if topRadius > 0 {
                path.addLine(to: CGPoint(x: w - topRadius, y: 0))
                path.addArc(
                    center: CGPoint(x: w - topRadius, y: topRadius),
                    radius: topRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: w, y: 0))       // Top-Right (Outer)
            }
            
            path.addLine(to: CGPoint(x: w, y: h - r))   // Down outer edge
            
            // Outer bottom-right corner (rounded, visible)
            path.addArc(
                center: CGPoint(x: w - r, y: h - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            
            path.addLine(to: CGPoint(x: 0, y: h))       // Bottom-Left (Inner)
            path.addLine(to: CGPoint(x: 0, y: 0))       // Up inner edge (STRAIGHT!)
            path.closeSubpath()
        }
        
        return path
    }
}


 
// Extension for Glass Edge Glow
extension View {
    func glassEdgeStroke(isLeft: Bool, isExpanded: Bool = false, isPlaying: Bool = false, albumColor: Color = .clear) -> some View {
        self.overlay(
            NotchWingShape(isLeft: isLeft, bottomRadius: isExpanded ? 0 : 14)
                .stroke(
                    LinearGradient(
                        colors: isPlaying
                            ? [albumColor.opacity(0.8), albumColor.opacity(0.1), .clear]
                            : [.white.opacity(0.4), .white.opacity(0.05), .clear],
                        startPoint: isLeft ? .topLeading : .topTrailing,
                        endPoint: isLeft ? .bottomTrailing : .bottomLeading
                    ),
                    lineWidth: 1
                )
                // Mask bottom edge when expanded to merge with panel
                .mask(Rectangle().padding(.bottom, isExpanded ? 1 : 0))
        )
    }
}

// Extension to easily apply inner stroke
extension View {
    func innerStroke<S: Shape, SS: ShapeStyle>(_ shape: S, style: SS, lineWidth: CGFloat = 1) -> some View {
        self.overlay(
            shape
                .stroke(style, lineWidth: lineWidth)
                .mask(shape)
                // Inset mask slightly to keep stroke inside?
                // Standard trick: Stroke width 2*lineWidth, masked by shape.
                // Or: Stroke centered, Masked by shape = Inner half visible.
        )
    }
}

// ─────────────────────────────────────────
// MARK: Trailing Wing (Acción / Estado)
// ─────────────────────────────────────────
// Muestra: estado contextual del sistema nervioso
// Ring con icono smart + breathing ambient

struct TrailingWingView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nervous = NervousSystem.shared
    @ObservedObject var system = SystemMonitor.shared
    
    @State private var tapPop = false
    @State private var ringGlow = false
    @State private var breathPhase = false
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            ZStack {
                // ── Ambient breathing glow (always on) ──
                if nervous.breathRate > 0 {
                    Circle()
                        .fill(ambientColor.opacity(breathPhase ? nervous.breathIntensity : 0.01))
                        .frame(width: DS.Layout.ringOuter, height: DS.Layout.ringOuter)
                        .blur(radius: 8)
                        .animation(
                            .easeInOut(duration: nervous.breathRate)
                                .repeatForever(autoreverses: true),
                            value: breathPhase
                        )
                    // Secondary halo (wider, fainter — premium depth)
                    Circle()
                        .fill(ambientColor.opacity(breathPhase ? nervous.breathIntensity * 0.3 : 0.0))
                        .frame(width: DS.Layout.ringOuter + 8, height: DS.Layout.ringOuter + 8)
                        .blur(radius: 12)
                        .animation(
                            .easeInOut(duration: nervous.breathRate * 1.3)
                                .repeatForever(autoreverses: true),
                            value: breathPhase
                        )
                }
                
                // ── Context ring ──
                ZStack {
                    // Outer glow track
                    Circle()
                        .stroke(ambientColor.opacity(0.06), lineWidth: 4)
                        .frame(width: DS.Layout.ringInner + 2, height: DS.Layout.ringInner + 2)
                        .blur(radius: 2)
                    
                    // Background track
                    Circle()
                        .stroke(ambientColor.opacity(0.15), lineWidth: 2.5)
                        .frame(width: DS.Layout.ringInner, height: DS.Layout.ringInner)
                    
                    // Progress arc (music = track progress, meeting = timer, else = subtle idle)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            ambientColor.opacity(0.8),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                            .frame(width: DS.Layout.ringInner, height: DS.Layout.ringInner)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: ringProgress)
                    
                    // Smart icon — changes based on context with scale bounce
                    Image(systemName: GestureEyeEngine.shared.gestureFlash ? "eye.fill" : nervous.smartIcon)
                        .font(.system(size: DS.Icons.micro, weight: .heavy))
                        .foregroundStyle(.white.opacity(tapPop ? 1.0 : 0.5))
                        .scaleEffect(tapPop ? 1.4 : 1.0)
                        .transition(.scale.combined(with: .opacity))
                        .id(nervous.smartIcon) // Trigger animation on icon change
                    
                    // Skip burst overlay
                    if ringGlow {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 3)
                            .frame(width: DS.Layout.ringInner, height: DS.Layout.ringInner)
                        Circle()
                            .fill(ambientColor.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .blur(radius: 5)
                    }
                    
                    // Song change glow
                    if viewModel.songChangeAlert {
                        Circle()
                            .fill(viewModel.albumColor.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .blur(radius: 4)
                    }
                    
                    // 👁️ Gesture flash only (no persistent indicator — macOS shows its own camera dot)
                    if GestureEyeEngine.shared.gestureFlash {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 28, height: 28)
                            .blur(radius: 3)
                            .transition(.opacity)
                    }
                }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isPlaying)
        .animation(DS.Spring.soft, value: nervous.currentMood)
        .scaleEffect(tapPop ? 1.2 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            handleSmartTap()
        }
        .onAppear {
            breathPhase = true
        }
    }
    
    // ── The ambient color: music overrides mood ──
    private var ambientColor: Color {
        if viewModel.isPlaying {
            return viewModel.albumColor
        }
        return nervous.moodColor
    }
    
    // ── Ring progress based on context ──
    private var ringProgress: Double {
        if viewModel.isPlaying {
            return viewModel.trackProgress
        }
        if nervous.isMeetingActive {
            // Meeting: fill over 60 minutes
            return min(nervous.meetingDuration / 3600.0, 1.0)
        }
        // Idle/Focus: subtle breathing arc
        return breathPhase ? 0.15 : 0.05
    }
    
    // ── Smart tap handler ──
    private func handleSmartTap() {
        switch nervous.smartAction {
        case .nextTrack:
            viewModel.nextTrack()
            HapticManager.shared.play(.button)
            
            // Flash animation
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                tapPop = true
                ringGlow = true
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.15)) {
                tapPop = false
            }
            withAnimation(DS.Spring.soft) {
                ringGlow = false
            }
            
        case .showMeeting:
            HapticManager.shared.play(.toggle)
            // Pop feedback — meeting info could expand panel
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                tapPop = true
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.15)) {
                tapPop = false
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.isExpanded.toggle()
            }
            
        case .expandPanel, .appAction:
            HapticManager.shared.play(.toggle)
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                tapPop = true
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.15)) {
                tapPop = false
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.isExpanded.toggle()
            }
            
        case .toggleTimer:
            HapticManager.shared.play(.button)
            viewModel.timerManager.timerActive.toggle()
        }
    }
}
