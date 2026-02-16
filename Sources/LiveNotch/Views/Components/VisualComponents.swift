import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 💎 Visual Effect Blur (NSVisualEffectView wrapper)
// ═══════════════════════════════════════════════════

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🖱️ Scroll Gesture Modifier (macOS)
// ═══════════════════════════════════════════════════

struct ScrollGestureModifier: ViewModifier {
    let handler: (CGFloat) -> Void
    @State private var monitor: Any?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    handler(event.scrollingDeltaY)
                    return event
                }
            }
            .onDisappear {
                if let monitor = monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
    }
}

extension View {
    func onScrollGesture(handler: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollGestureModifier(handler: handler))
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 👆 Swipe Gesture Modifier (Premium v2)
// ═══════════════════════════════════════════════════
// ✅ Low 25pt threshold for easy triggering
// ✅ Glowing progress bar along bottom edge
// ✅ Direction preview text (⏭ Next / ⏮ Prev)
// ✅ Rubber-band visual offset
// ✅ Vertical scroll → volume control
// ✅ 0.6s debounce anti-double-skip
// ✅ Haptic ramp: tick at 60%, success at trigger

struct SwipeGestureModifier: ViewModifier {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    var onVerticalScroll: ((CGFloat) -> Void)? = nil
    
    @State private var monitor: Any?
    @State private var accDX: CGFloat = 0
    @State private var swipeOffset: CGFloat = 0
    @State private var resetTimer: Timer?
    @State private var isOnCooldown = false
    @State private var hapticStage = 0 // 0=none, 1=tick, 2=fired
    @State private var triggered = false
    
    private let threshold: CGFloat = 25 // Lower = easier to trigger
    private let cooldown: TimeInterval = 0.6
    
    private var progress: CGFloat {
        min(1.0, abs(accDX) / threshold)
    }
    
    private var direction: Int {
        accDX < -threshold * 0.2 ? -1 : (accDX > threshold * 0.2 ? 1 : 0)
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                // Rubber-band offset
                .offset(x: rubberBand(swipeOffset, limit: 10))
                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.7), value: swipeOffset)
            
            // ─── Progress bar (bottom edge glow) ───
            if progress > 0.1 && !triggered {
                GeometryReader { geo in
                    let barWidth = geo.size.width * progress
                    let barColor: Color = progress > 0.8 ? .green : (direction < 0 ? .cyan : .orange)
                    
                    ZStack(alignment: direction < 0 ? .trailing : .leading) {
                        // Track
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 2)
                        
                        // Fill
                        Rectangle()
                            .fill(barColor)
                            .frame(width: barWidth, height: 2)
                            .shadow(color: barColor.opacity(0.8), radius: 4, y: 0)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
            
            // ─── Direction label ───
            if progress > 0.3 && !triggered {
                HStack(spacing: 4) {
                    Image(systemName: direction < 0 ? "forward.fill" : "backward.fill")
                        .font(.system(size: 8, weight: .heavy))
                    Text(direction < 0 ? "Next" : "Prev")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(Double(progress) * 0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(Double(progress) * 0.1))
                )
                .scaleEffect(progress > 0.8 ? 1.1 : 0.9)
                .offset(y: -4)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: progress)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
                .allowsHitTesting(false)
            }
            
            // ─── Success flash ───
            if triggered {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .clear],
                            startPoint: direction < 0 ? .leading : .trailing,
                            endPoint: direction < 0 ? .trailing : .leading
                        )
                    )
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { startMonitor() }
        .onDisappear { stopMonitor() }
    }
    
    private func startMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // ── Vertical scroll → volume ──
            if let vHandler = onVerticalScroll, abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                vHandler(event.scrollingDeltaY)
                return event
            }
            
            // ── Horizontal → skip ──
            guard abs(event.scrollingDeltaX) > 0.5, !isOnCooldown else { return event }
            accDX += event.scrollingDeltaX
            
            // Visual offset
            withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.75)) {
                swipeOffset = accDX * 0.4
            }
            
            // Haptic ramp
            let p = abs(accDX) / threshold
            if p > 0.6 && hapticStage == 0 {
                HapticManager.shared.play(.alignment)
                hapticStage = 1
            }
            
            // Reset timer
            resetTimer?.invalidate()
            resetTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                DispatchQueue.main.async { resetState() }
            }
            
            // Trigger!
            if abs(accDX) >= threshold {
                fireSwipe()
            }
            return event
        }
    }
    
    private func fireSwipe() {
        guard !isOnCooldown else { return }
        
        let dir = accDX < 0
        if dir { onSwipeLeft() } else { onSwipeRight() }
        HapticManager.shared.play(.success)
        hapticStage = 2
        
        // Visual: triggered flash
        withAnimation(DS.Spring.micro) { triggered = true }
        
        // Bounce offset
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            swipeOffset = dir ? -18 : 18
        }
        
        // Cooldown
        isOnCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
            isOnCooldown = false
        }
        
        // Reset after bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            resetState()
        }
    }
    
    private func resetState() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            accDX = 0
            swipeOffset = 0
            triggered = false
        }
        hapticStage = 0
    }
    
    private func stopMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        resetTimer?.invalidate()
    }
    
    private func rubberBand(_ offset: CGFloat, limit: CGFloat) -> CGFloat {
        let s: CGFloat = offset >= 0 ? 1 : -1
        let a = abs(offset)
        return a <= limit ? offset : s * (limit + (a - limit) * 0.25)
    }
}

extension View {
    func onSwipeGesture(
        left: @escaping () -> Void,
        right: @escaping () -> Void,
        volume: ((CGFloat) -> Void)? = nil
    ) -> some View {
        modifier(SwipeGestureModifier(onSwipeLeft: left, onSwipeRight: right, onVerticalScroll: volume))
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Visual Components — Extracted & Enhanced
// ═══════════════════════════════════════════════════

extension NotchView {
    
    // ═══════════════════════════════════════
    // MARK: - Notch Background
    // ═══════════════════════════════════════
    
    func notchBackground() -> some View {
        ZStack {
            if viewModel.isLiquidGlassEnabled {
                // 💎 Liquid Glass — Native API on Tahoe, custom fallback
                if #available(macOS 26.0, *) {
                    // ── Native Liquid Glass (macOS Tahoe 26+) ──
                    // Real refraction, specular highlights, frosted depth
                    
                    // Base glass surface
                    Color.clear
                        .glassEffect(
                            .regular.tint(
                                viewModel.isPlaying
                                    ? viewModel.albumColor.opacity(0.3)
                                    : Color.white.opacity(0.05)
                            ),
                            in: .rect(cornerRadius: 0)
                        )
                    
                    // Album art subtle bleed for warmth
                    if viewModel.isPlaying, let art = viewModel.albumArtImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 70)
                            .opacity(0.06)
                            .scaleEffect(2.5)
                            .clipped()
                            .blendMode(.plusLighter)
                    }
                } else {
                    // ── Fallback: Custom multi-layer glass (macOS 14-15) ──
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                        .opacity(0.3)
                    
                    // 🎨 Mode Tint (Light)
                    ThemeEngine.shared.activeTheme.accentColor.opacity(0.15)
                        .blendMode(.screen)
                        
                    Color.black.opacity(0.2)
                    
                    // Specular highlight — warm champagne tint
                    LinearGradient(
                        stops: [
                            .init(color: DS.Colors.champagneGold.opacity(0.06), location: 0.0),
                            .init(color: .white.opacity(0.04), location: 0.15),
                            .init(color: .clear, location: 0.4),
                            .init(color: .clear, location: 0.85),
                            .init(color: DS.Colors.champagneGold.opacity(0.02), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Inner edge highlight — liquid glass border
                    RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DS.Colors.champagneGold.opacity(0.10),
                                    .white.opacity(0.06),
                                    .clear,
                                    DS.Colors.champagneGold.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                        .blendMode(.plusLighter)
                    
                    // Album tint when playing
                    if viewModel.isPlaying, let art = viewModel.albumArtImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .opacity(0.12)
                            .scaleEffect(2.5)
                            .clipped()
                        
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.15)],
                            center: .center,
                            startRadius: 30,
                            endRadius: 180
                        )
                    }
                }
            } else {
                // Opaque mode: subtle gradient
                LinearGradient(
                    colors: [Color.black, Color(white: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Album art blurred backdrop
                if viewModel.isExpanded, viewModel.isPlaying, let art = viewModel.albumArtImage {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 40)
                        .opacity(0.12)
                        .scaleEffect(1.8)
                        .clipped()
                    
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 200
                    )
                }
            }
            
            // Gesture Glow Effect (Subtle feedback)
            NotchGlowView(viewModel: viewModel)
        }
    }
    
    
    // ═══════════════════════════════════════
    // MARK: - Ambient Glow
    // ═══════════════════════════════════════
    
    func ambientGlow() -> some View {
        ZStack {
            // 1. Base Mode Glow (Persistent)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [ThemeEngine.shared.activeTheme.accentColor.opacity(ThemeEngine.shared.activeTheme.glowIntensity * 0.45), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(100, currentWidth * 0.9)
                    )
                )
                .frame(width: max(200, currentWidth * 1.4), height: max(100, currentHeight * 1.8))
                .blur(radius: 40)
            
            // 2. Psionic/High-Energy Extra Glow (Top Down)
            if ThemeEngine.shared.activeTheme.glowIntensity > 0.8 {
                 Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [ThemeEngine.shared.activeTheme.accentColor.opacity(0.4), .clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 320, height: 180)
                    .offset(y: -50)
                    .blur(radius: 25)
            }
            
            // 3. Album Art Glow (When playing)
            if viewModel.isPlaying && viewModel.albumArtImage != nil {
                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [viewModel.albumColor.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: currentWidth * 0.7
                            )
                        )
                        .frame(width: currentWidth * 1.3, height: currentHeight * 1.6)
                        .offset(y: currentHeight * 0.3)
                    
                    // Secondary color glow
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [viewModel.albumColor2.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: currentWidth * 0.6
                            )
                        )
                        .frame(width: currentWidth * 0.8, height: currentHeight)
                        .offset(x: currentWidth * 0.2, y: currentHeight * 0.2)
                }
                .blur(radius: 30)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Glance HUD
    // ═══════════════════════════════════════
    
    func glanceHUD(_ glance: NotchViewModel.GlanceNotification) -> some View {
        HStack(spacing: 8) {
            if let icon = glance.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: DS.Layout.glanceIcon, height: DS.Layout.glanceIcon)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .shadow(color: DS.Shadow.md, radius: 2, y: 1)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(glance.appName)
                    .font(DS.Fonts.bodySemi)
                    .foregroundColor(DS.Colors.textPrimary)
                Text(glance.title)
                    .font(DS.Fonts.tinyRound)
                    .foregroundColor(DS.Colors.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.black.opacity(0.45))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: DS.Shadow.xl, radius: 12, x: 0, y: 6)
    }
    
    // ═══════════════════════════════════════
    // MARK: - 💡 Tip HUD
    // ═══════════════════════════════════════
    
    func tipHUD(_ tip: TipEngine.Tip) -> some View {
        HStack(spacing: 8) {
            // Lightbulb icon with amber glow
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: DS.Layout.glanceIcon + 4, height: DS.Layout.glanceIcon + 4)
                Image(systemName: tip.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("TIP")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.orange.opacity(0.2))
                        )
                    Text(tip.appName)
                        .font(DS.Fonts.tinyRound)
                        .foregroundColor(DS.Colors.textMuted)
                }
                Text(tip.text)
                    .font(DS.Fonts.tinyRound)
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: 320)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.black.opacity(0.5))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.orange.opacity(0.1), radius: 12, x: 0, y: 6)
        .shadow(color: DS.Shadow.xl, radius: 8, x: 0, y: 4)
    }
    
    // ═══════════════════════════════════════
    // MARK: - BT Connect Overlay
    // ═══════════════════════════════════════
    
    func btConnectOverlay(device: BluetoothMonitor.BTDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.icon)
                .font(.system(size: DS.Icons.large, weight: .medium))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.6), radius: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected")
                    .font(DS.Fonts.tiny)
                    .foregroundColor(DS.Colors.textTertiary)
                Text(device.name)
                    .font(DS.Fonts.labelBold)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .fill(Color.black.opacity(0.4))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .stroke(Color.blue.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, y: 4)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Action Button (Bottom Bar)
    // ═══════════════════════════════════════
    
    func actionButton(icon: String, label: String, index: Int = 0, action: @escaping () -> Void) -> some View {
        let tintColor = viewModel.isPlaying ? viewModel.albumColor : Color.white
        
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DS.Icons.body, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: DS.Layout.actionButtonH)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [tintColor.opacity(0.12), tintColor.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }
}

// ═══════════════════════════════════════
// MARK: - 🌟 Notch Glow Effect
// ═══════════════════════════════════════

struct NotchGlowView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        ZStack {
            if viewModel.showGestureFeedback {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    switch viewModel.lastGesture {
                    case .rightWink:
                        // Right side glow (Cyan) — wink right -> next track -> right side
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [Color.cyan.opacity(0.8), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 40)
                            .position(x: w - 30, y: h - 10)
                            .blur(radius: 8)
                        
                    case .leftWink:
                        // Left side glow (Cyan) — wink left -> prev track -> left side
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [Color.cyan.opacity(0.8), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 40)
                            .position(x: 30, y: h - 10)
                            .blur(radius: 8)
                        
                    case .slowBlink:
                        // Center glow (Green) — play/pause
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [Color.green.opacity(0.7), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 100, height: 50)
                            .position(x: w / 2, y: h - 5)
                            .blur(radius: 12)
                        
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}


// ═══════════════════════════════════════
// MARK: - 🍅 Pomodoro Progress
// ═══════════════════════════════════════

struct TimerProgressView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        if viewModel.timerActive {
            GeometryReader { geo in
                let w = geo.size.width
                // Progress: 0.0 (start) -> 1.0 (end)
                // Actually timerSeconds counts DOWN.
                // So progress = 1.0 - (timerSeconds / totalSeconds)
                let totalSeconds = Double(max(1, viewModel.pomodoroMinutes * 60))
                let current = Double(viewModel.timerSeconds)
                let progress = 1.0 - (current / totalSeconds)
                
                // Color ramp: Green -> Yellow -> Red
                let color: Color = progress < 0.5 ? .green : (progress < 0.85 ? .yellow : .red)
                
                ZStack(alignment: .leading) {
                    // Background track (very subtle)
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1.5)
                    
                    // Progress bar
                    Rectangle()
                        .fill(color)
                        .frame(width: w * CGFloat(progress), height: 1.5)
                        .animation(.linear(duration: 1.0), value: progress)
                        // Glow for visibility
                        .shadow(color: color.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                .position(x: w/2, y: geo.size.height - 1)
            }
            .frame(height: 2)
            .transition(.opacity)
        }
    }
}
