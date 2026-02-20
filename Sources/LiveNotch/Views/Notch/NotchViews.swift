import SwiftUI
import AppKit

import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════
// MARK: - NOTCH//WINGS — Main View (Borderless Overlay)
// ═══════════════════════════════════════════════════
// Ventana estrecha (~585pt) centrada en el notch, NO full screen.
//
// Layout (collapsed):  window height = 32pt (notch height)
//   |── LEFT WING ──|── notch gap ──|── RIGHT WING ──|
//
// Layout (expanded):   window grows to 380pt
//   |── LEFT WING ──|── notch gap ──|── RIGHT WING ──|
//   |────────── PANEL (centered below) ──────────────|

struct NotchView: View {
    
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var clipboard = ClipboardManager.shared
    @ObservedObject var calendar = CalendarService.shared
    @ObservedObject var weather = WeatherService.shared
    @ObservedObject var brainDump = BrainDumpManager.shared
    @ObservedObject var bluetooth = BluetoothMonitor.shared
    @ObservedObject var mixer = PerAppVolumeMixer.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var profile = ProfileManager.shared
    @ObservedObject var nervous = NervousSystem.shared
    @ObservedObject var notchBrain = NotchIntelligence.shared
    
    @StateObject var cameraService = CameraService()
    
    let geometry: NotchGeometry
    
    let mirrorWidth: CGFloat = 340
    let trayWidth: CGFloat = 360
    let clipboardWidth: CGFloat = 320
    let panelWidth: CGFloat = 400
    
    @State private var isHovered = false
    @State private var hoverTimer: Timer?
    @State private var currentDate = Date()
    @State private var dateTimer: Timer? = nil
    
    // Micro-animation states
    @State private var breathingPhase = false
    @State private var shinePosition: CGFloat = -0.5
    @State private var badgeBounce = false
    @State private var lastBrainDumpCount = 0
    @State private var edgeBreathPhase = false
    
    // Peek mode
    @State private var isPeeking = false
    

    // Nervous system glow color
    private var nervousGlowColor: Color {
        viewModel.isPlaying ? viewModel.albumColor : DS.Colors.yinmnBlue
    }
    
    /// Bio-luminescent glow — the notch "breathes" based on system state
    private var bioGlowColor: Color {
        viewModel.bioLum.glowColor
    }
    
    private var bioGlowIntensity: Double {
        viewModel.bioLum.glowIntensity
    }
    
    init(viewModel: NotchViewModel, geometry: NotchGeometry) {
        self.viewModel = viewModel
        self.geometry = geometry
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Layer 1: Normal Content
                if isAnyPanelActive {
                    // ═══ EXPANDED: Unified single shape ═══
                    unifiedExpandedView()
                        .onHover { hovering in handleHover(hovering) }
                        .rotation3DEffect(
                            .degrees(isAnyPanelActive ? 0 : -35),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .top
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        ))
                } else {
                    // ═══ COLLAPSED: Independent wings ═══
                    wingsRow()
                        .opacity((isHovered || !viewModel.isMinimalMode) ? 1.0 : 0.1)
                        .blur(radius: (isHovered || !viewModel.isMinimalMode) ? 0 : 1.5)
                        .animation(DS.Spring.island, value: viewModel.isMinimalMode)
                        .onHover { hovering in handleHover(hovering) }
                }
                
                // Layer 2: Status Toast (Overlay)
                if let msg = viewModel.statusMessage {
                    StatusToastView(
                        message: msg,
                        icon: viewModel.statusIcon,
                        width: geometry.windowWidth,
                        height: geometry.notchHeight
                    )
                    .zIndex(100)
                }
                
                // Layer 3: Glance & Tip HUD (below notch, priority: glance > tip)
                VStack {
                    Spacer().frame(height: geometry.notchHeight + 4)
                    
                    if let glance = viewModel.glanceNotification {
                        glanceHUD(glance)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                            .zIndex(90)
                    } else if let tip = viewModel.tipNotification {
                        tipHUD(tip)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                            .zIndex(89)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.glanceNotification != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.tipNotification != nil)
                
                // Integrated HUD Overlay (Volume/Brightness)
                IntegratedHUDView()
                    .offset(y: geometry.notchHeight + 4)
                    .zIndex(150)
                
                // Pomodoro Progress (Bottom Edge)
                TimerProgressView(viewModel: viewModel)
            }
            .opacity(viewModel.statusMessage != nil && !isAnyPanelActive ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage != nil)
            
            Spacer(minLength: 0)
        }
        .frame(width: geometry.windowWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .onDrop(of: [UTType.item, UTType.image, UTType.text], isTargeted: $viewModel.isDropTargetActive) { providers in
            handleFileDrop(providers)
        }
        .onChange(of: viewModel.isMirrorActive) {
            if viewModel.isMirrorActive { cameraService.start() } else { cameraService.stop() }
        }
        .onAppear {
            dateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                currentDate = Date()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isAnyPanelActive)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Wings Row (Top of Window = Top of Screen)
    // ═══════════════════════════════════════
    
    private var dynamicWingWidth: CGFloat {
        geometry.wingContentWidth
    }
    
    private func wingsRow() -> some View {
        let totalWidth = (dynamicWingWidth * 2) + geometry.notchWidth
        
        return ZStack {
            // ██ SOLID BLACK BASE — guarantees zero transparency in collapsed ██
            HStack(spacing: 0) {
                NotchWingShape(isLeft: true, bottomRadius: 14)
                    .fill(Color.black)
                    .frame(width: dynamicWingWidth, height: geometry.notchHeight)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geometry.notchWidth, height: geometry.notchHeight)
                NotchWingShape(isLeft: false, bottomRadius: 14)
                    .fill(Color.black)
                    .frame(width: dynamicWingWidth, height: geometry.notchHeight)
            }
            
            // 0. The Liquid Organism (on top of solid black)
            LiquidNotchView(
                width: totalWidth,
                height: geometry.notchHeight,
                topRadius: 0,
                bottomRadius: 14,
                color: .black
            )
            .shadow(color: .black.opacity(0.8), radius: 18, x: 0, y: 8)  // ALCOVE deep shadow
            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)   // Tight contact shadow
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)   // Crisp edge shadow
            
            // 1. Content Layer
            HStack(spacing: 0) {
                // ─── Left Wing ───
                LeadingWingView(viewModel: viewModel)
                    .frame(width: dynamicWingWidth, height: geometry.notchHeight, alignment: .trailing)
                
                // ─── Notch Gap (Invisible Touch Area) ───
                Color.black.opacity(0.001) // Invisible but tappable
                    .frame(width: geometry.notchWidth, height: geometry.notchHeight)
                    .contentShape(Rectangle())
                    .overlay {
                        // Swarm particles visible in collapsed state
                        if !viewModel.swarm.livingAgents.isEmpty {
                            SwarmParticleView(swarm: viewModel.swarm)
                                .allowsHitTesting(false)
                        }
                    }
                    // 🔒 Privacy Shutter — frosted glass over camera
                    .overlay {
                        if PrivacyShutter.shared.shutterAnimation {
                            ZStack {
                                // Frosted glass layer
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .opacity(PrivacyShutter.shared.frostLevel)
                                    .blur(radius: PrivacyShutter.shared.frostLevel * 3)
                                
                                // Frost crystallization pattern
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15 * PrivacyShutter.shared.frostLevel),
                                                Color.white.opacity(0.05 * PrivacyShutter.shared.frostLevel),
                                                Color.white.opacity(0.1 * PrivacyShutter.shared.frostLevel)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                // Lock icon
                                Image(systemName: PrivacyShutter.shared.isEngaged ? "lock.fill" : "lock.open.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6 * PrivacyShutter.shared.frostLevel))
                                    .scaleEffect(PrivacyShutter.shared.isEngaged ? 1.0 : 0.8)
                            }
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }
                    }
                    .onTapGesture {
                        HapticManager.shared.play(.toggle)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            viewModel.isExpanded.toggle()
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        // Long press → toggle privacy shutter
                        PrivacyShutter.shared.toggle()
                    }
                
                TrailingWingView(viewModel: viewModel)
                    .frame(width: dynamicWingWidth, height: geometry.notchHeight, alignment: .leading)
            }
        }
        .frame(height: geometry.notchHeight)
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4) // ALCOVE bottom depth
        // Bio-luminescent breathing edge (ALCOVE premium)
        .overlay(alignment: .bottom) {
            if edgeBreathPhase || !edgeBreathPhase { // Always render, animate via opacity
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                nervousGlowColor.opacity(edgeBreathPhase ? 0.08 : 0.02),
                                nervousGlowColor.opacity(edgeBreathPhase ? 0.15 : 0.03),
                                nervousGlowColor.opacity(edgeBreathPhase ? 0.08 : 0.02),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: totalWidth * 0.6, height: 1)
                    .blur(radius: 2)
                    .offset(y: -0.5)
                    .animation(
                        .easeInOut(duration: nervous.breathRate > 0 ? nervous.breathRate : 3.0)
                            .repeatForever(autoreverses: true),
                        value: edgeBreathPhase
                    )
            }
        }
        .onAppear { edgeBreathPhase = true }
        // Peek preview below wings
        .overlay(alignment: .bottom) {
            if isPeeking {
                peekView()
                    .offset(y: geometry.notchHeight + 4)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                        )
                    )
            }
        }
        .scaleEffect(isHovered && !isAnyPanelActive ? 1.012 : 1.0) // Premium: subtle hover lift
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isHovered) // Snappier
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.songChangeAlert)
        .onSwipeGesture(
            left: {
                viewModel.nextTrack()
                viewModel.showStatus("⏭️ Next", icon: "forward.fill")
            },
            right: {
                viewModel.previousTrack()
                viewModel.showStatus("⏮️ Previous", icon: "backward.fill")
            },
            volume: { deltaY in
                handleScrollVolume(delta: deltaY)
            }
        )
    }
    

    
    var volumeIcon: String {
        if viewModel.volume <= 0 { return "speaker.slash.fill" }
        if viewModel.volume <= 33 { return "speaker.wave.1.fill" }
        if viewModel.volume <= 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // ─── Peek View (mini music card) ───
    private func peekView() -> some View {
        HStack(spacing: 10) {
            if let art = viewModel.albumArtImage {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentTrack)
                    .font(DS.Fonts.labelSemi)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(viewModel.currentArtist)
                    .font(DS.Fonts.small)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(viewModel.albumColor.opacity(0.6))
                            .frame(width: geo.size.width * viewModel.trackProgress)
                    }
                }
                .frame(height: 3)
            }
            
            Spacer(minLength: 0)
            
            // Play/Pause button
            Button(action: {
                viewModel.togglePlayPause()
                HapticManager.shared.play(.toggle)
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(DS.Fonts.h4)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: dynamicWingWidth * 2 + geometry.notchWidth)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .stroke(viewModel.albumColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }
    
    // ─── Scroll → Volume handler (Smooth) ───
    @State private var volumeAccumulator: CGFloat = 0
    @State private var targetVolume: Float = -1
    @State private var smoothTimer: Timer?
    
    private func handleScrollVolume(delta: CGFloat) {
        // Initialize target on first use
        if targetVolume < 0 { targetVolume = viewModel.volume }
        
        // Velocity-adaptive: slow = fine, fast = coarser
        let speed = abs(delta)
        let sensitivity: Float = speed > 5 ? 0.3 : 0.1
        
        // Apply delta to target
        targetVolume = max(0, min(100, targetVolume + Float(delta) * sensitivity))
        
        // Haptic only at boundaries (0% or 100%)
        if (targetVolume <= 0 && viewModel.volume > 0) || (targetVolume >= 100 && viewModel.volume < 100) {
            HapticManager.shared.play(.alignment)
        }
        
        // PERF: 30fps lerp is perceptually identical for volume (was 60fps)
        if smoothTimer == nil {
            smoothTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    let current = viewModel.volume
                    let diff = targetVolume - current
                    
                    if abs(diff) < 0.3 {
                        // Close enough — snap and stop
                        viewModel.adjustVolume(by: diff)
                        smoothTimer?.invalidate()
                        smoothTimer = nil
                    } else {
                        // Lerp 25% toward target each frame
                        let change = diff * 0.25
                        viewModel.adjustVolume(by: change)
                        
                        // Sync Integrated HUD immediately for responsiveness
                        Task { @MainActor in
                            IntegratedHUDManager.shared.value = (current + change) / 100
                            IntegratedHUDManager.shared.show(.volume)
                        }
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Unified Expanded View (ONE organic shape)
    // ═══════════════════════════════════════
    // Wings + panel as a single continuous container.
    // No seam, no gap, one background, one clipShape.
    
    // Panel width = wings + notch
    private var visualWidth: CGFloat {
        geometry.wingContentWidth * 2 + geometry.notchWidth
    }

    private func unifiedExpandedView() -> some View {
        VStack(spacing: 0) {
            // ── Top bar: unique info in wings (not duplicated in panel) ──
            // Left = battery (unique), Right = collapse chevron
            HStack(spacing: 0) {
                // Left wing: battery indicator (not shown elsewhere in panel)
                HStack(spacing: 3) {
                    Spacer()
                    Image(systemName: viewModel.batteryIcon)
                        .font(DS.Fonts.micro)
                        .foregroundStyle(viewModel.isCharging ? .green.opacity(0.7) : DS.Colors.textMuted)
                    Text("\(viewModel.batteryLevel)%")
                        .font(DS.Fonts.microBold)
                        .foregroundStyle(DS.Colors.textMuted)
                    Spacer()
                }
                .frame(width: geometry.wingContentWidth, height: geometry.notchHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.play(.toggle)
                    toggleExpanded()
                }
                
                // Notch gap — tap to collapse
                Color.clear
                    .frame(width: geometry.notchWidth, height: geometry.notchHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.play(.toggle)
                        toggleExpanded()
                    }
                
                // Right wing: collapse chevron
                HStack(spacing: 0) {
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(DS.Fonts.microBold)
                        .foregroundStyle(DS.Colors.textGhost)
                    Spacer()
                }
                .frame(width: geometry.wingContentWidth, height: geometry.notchHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.play(.toggle)
                    toggleExpanded()
                }
            }
            .frame(height: geometry.notchHeight)
            
            // ── Panel content flows directly below ──
            expandedPanel()
        }
        .frame(width: visualWidth)
        .background(
            ZStack {
                // ██ SOLID BLACK BASE — guarantees zero transparency ██
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                
                // Liquid Metal Background — Alcove-level deep black
                LiquidNotchView(
                   width: 0, height: 0, // Ignored because useProxySize is true
                   topRadius: 0,
                   bottomRadius: 22,
                   color: .black,
                   useProxySize: true
                )
                .shadow(color: .black.opacity(0.75), radius: 28, y: 14)  // Deep abyss shadow
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)    // Tight inner shadow
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)     // Crisp contact shadow
                
                // Inner glass edge highlight — the subtle "premium" feeling
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),    // Top: invisible
                            Color.white.opacity(0.0),    // Body: void
                            Color.white.opacity(0.003),  // Mid: ghost
                            Color.white.opacity(0.008)   // Bottom: whisper
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 1) // Below notch cutout
                
                // Specular sweep — animated shine across surface
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.008), .clear],
                        startPoint: UnitPoint(x: shinePosition, y: 0),
                        endPoint: UnitPoint(x: shinePosition + 0.4, y: 1)
                    )
                )
                .padding(.top, 1)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                        shinePosition = 1.5
                    }
                }
                
                // Ambient Glow (on top of black liquid)
                ambientGlow()
            }
        )
        // clipShape removed, relying on shader transparency (visual only)
        // Note: Interactive areas must be within the shape.
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            )
            .stroke(
                viewModel.isPlaying
                    ? AnyShapeStyle(AngularGradient(
                        colors: [viewModel.albumColor.opacity(0.12), viewModel.albumColor2.opacity(0.06), viewModel.albumColor.opacity(0.03)],
                        center: .center
                      ))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.05),
                                .white.opacity(0.12),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                      ),
                lineWidth: 0.6
            )
            .mask(
                VStack(spacing: 0) {
                    Color.clear.frame(height: 2)
                    Color.white
                }
            )
        )
        .shadow(color: viewModel.isPlaying ? viewModel.albumColor.opacity(0.08) : DS.Shadow.deep, radius: 24, y: 12)
    }
    private func expandedPanel() -> some View {
        VStack(spacing: 0) {
            // ─── Header: Profile + Time + Close ───
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: profile.currentProfile.icon)
                        .font(DS.Fonts.tinySemi)
                        .foregroundStyle(profileAccent.opacity(0.6))
                    Text(profile.currentProfile.name.uppercased())
                        .font(DS.Fonts.microBold)
                        .foregroundStyle(DS.Colors.textGhost)
                        .tracking(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(timeString)
                        .font(DS.Fonts.labelMono)
                        .foregroundStyle(.white.opacity(0.35))
                        .monospacedDigit()
                    Text(dateString)
                        .font(.system(size: 6.5, weight: .medium)) // 6.5pt — too small for token
                        .foregroundStyle(.white.opacity(0.15))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Button(action: {
                    HapticManager.shared.play(.toggle)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        collapseAll()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DS.Fonts.body)
                        .foregroundColor(.white.opacity(0.15))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)
            
            // ═══ CONTENT ═══
            if viewModel.isMirrorActive {
                MirrorPanelView(viewModel: viewModel, cameraService: cameraService)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: UnitPoint.top)))
            } else if viewModel.isClipboardVisible {
                ClipboardPanelView(viewModel: viewModel, clipboard: clipboard)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isBrainDumpVisible {
                MindflowPanelView(viewModel: viewModel, brainDump: brainDump)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isVolumeMixerVisible {
                VolumeMixerPanelView(viewModel: viewModel, mixer: mixer)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isEyeControlVisible {
                EyeControlPanelView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isQuickLaunchVisible {
                QuickLaunchPanelView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .center)))
            } else if viewModel.isSwarmVisible {
                SwarmPanelView(swarm: viewModel.swarm, viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isCalendarVisible {
                CalendarPanelView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isSettingsVisible {
                SettingsPanelView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isEcosystemHubVisible {
                EcosystemHubView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if viewModel.isCortexVisible {
                CortexPanelView(cortex: viewModel.cortex, viewModel: viewModel)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            } else if !viewModel.droppedFiles.isEmpty {
                TrayPanelView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: UnitPoint.top)))
            } else {
                mainExpandedPanel()
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isMirrorActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isClipboardVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isBrainDumpVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isVolumeMixerVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isEyeControlVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isQuickLaunchVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isSwarmVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isCalendarVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isSettingsVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isEcosystemHubVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.isCortexVisible)
    }
    
    // ── Static formatters (avoid recreating on every render — perf fix) ──
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE d MMM"
        return f
    }()
    
    private var timeString: String {
        Self.timeFormatter.string(from: currentDate)
    }
    
    private var dateString: String {
        Self.dateFormatter.string(from: currentDate)
    }
    
    // ═══════════════════════════════════════
    // MARK: - State Helpers
    // ═══════════════════════════════════════
    
    var isAnyPanelActive: Bool {
        viewModel.isExpanded || viewModel.isMirrorActive || viewModel.isClipboardVisible ||
        viewModel.isBrainDumpVisible || viewModel.isVolumeMixerVisible || viewModel.isEyeControlVisible || viewModel.isQuickLaunchVisible || viewModel.isSwarmVisible || viewModel.isCalendarVisible || viewModel.isSettingsVisible || viewModel.isEcosystemHubVisible || viewModel.isCortexVisible || !viewModel.droppedFiles.isEmpty
    }
    
    private func collapseAll() {
        viewModel.isExpanded = false
        viewModel.isMirrorActive = false
        viewModel.isClipboardVisible = false
        viewModel.isBrainDumpVisible = false
        viewModel.isVolumeMixerVisible = false
        viewModel.isEyeControlVisible = false
        viewModel.isQuickLaunchVisible = false
        viewModel.isSwarmVisible = false
        viewModel.isCalendarVisible = false
        viewModel.isSettingsVisible = false
        viewModel.isEcosystemHubVisible = false
        viewModel.isCortexVisible = false
        viewModel.showVolumeSlider = false
    }
    
    private func toggleExpanded() {
        HapticManager.shared.play(.toggle)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isAnyPanelActive {
                collapseAll()
            } else {
                viewModel.isExpanded = true
            }
        }
    }
    
    var profileAccent: Color {
        switch profile.currentProfile.accentColor {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "indigo": return .indigo
        case "red": return .red
        case "yinmn": return DS.Colors.yinmnBlue
        case "klein": return DS.Colors.kleinBlue
        default: return .white
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Main Expanded Panel
    // ═══════════════════════════════════════
    
    func mainExpandedPanel() -> some View {
        VStack(spacing: 8) {
            musicSection()
            
            // Album-tinted separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: viewModel.isPlaying
                            ? [.clear, viewModel.albumColor.opacity(0.2), .clear]
                            : [.clear, Color.white.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .padding(.horizontal, 4)
            
            // ── AI Bar ──
            aiBar()
            
            // ── Action Grid (below AI) ──
            if !viewModel.showAIBar || viewModel.aiResponse.isEmpty {
                bottomActionBar()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    // ═══════════════════════════════════════
    // MARK: - AI Bar (Notch Brain)
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func aiBar() -> some View {
        if true { // NotchIntelligence is always available (local engine)
            VStack(spacing: 4) {
                if viewModel.showAIBar {
                    // ── Expanded: text field + response ──
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(DS.Fonts.body)
                            .foregroundColor(.purple.opacity(0.8))
                        
                        TextField(L10n.aiPlaceholder, text: $viewModel.aiQuery)
                            .font(DS.Fonts.small)
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                viewModel.sendAIQuery()
                            }
                        
                        if viewModel.aiIsThinking {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Button(action: {
                                withAnimation(DS.Anim.springFast) {
                                    viewModel.showAIBar = false
                                    viewModel.aiResponse = ""
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(DS.Fonts.body)
                                    .foregroundColor(DS.Colors.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.vertical, DS.Space.sm)
                    .background(DS.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(
                                viewModel.aiIsThinking 
                                    ? Color.purple.opacity(0.3) 
                                    : DS.Colors.strokeLight,
                                lineWidth: 0.5
                            )
                    )
                    
                    // ── AI Response bubble ──
                    if viewModel.aiIsThinking {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(Color.purple.opacity(0.6))
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(viewModel.aiIsThinking ? 1.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                                        value: viewModel.aiIsThinking
                                    )
                            }
                            Text(L10n.aiThinking)
                                .font(DS.Fonts.micro)
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if !viewModel.aiResponse.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(viewModel.aiResponse)
                                .font(DS.Fonts.tiny)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 80)
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, DS.Space.sm)
                        .background(Color.purple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(Color.purple.opacity(0.15), lineWidth: 0.5)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    // ── Collapsed: mini pill button ──
                    Button(action: {
                        withAnimation(DS.Anim.springStd) {
                            viewModel.showAIBar = true
                        }
                        HapticManager.shared.play(.button)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(DS.Fonts.tiny)
                                .foregroundColor(.purple.opacity(0.7))
                            Text(L10n.aiPlaceholder)
                                .font(DS.Fonts.micro)
                                .foregroundColor(DS.Colors.textMuted)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, 3)
                        .background(DS.Colors.surfaceFaint)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(DS.Colors.strokeFaint, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 2)
            .animation(DS.Anim.springStd, value: viewModel.showAIBar)
            .animation(DS.Anim.springStd, value: viewModel.aiResponse)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Bottom Action Bar
    // ═══════════════════════════════════════
    
    func bottomActionBar() -> some View {
        let columns = [GridItem](repeating: GridItem(.flexible(), spacing: DS.Space.sm), count: 4)
        
        return LazyVGrid(columns: columns, spacing: DS.Space.sm) {
            // Row 1: Core tools
            gridButton(
                icon: "camera.fill", label: L10n.mirror,
                isActive: viewModel.isMirrorActive,
                tint: .cyan
            ) {
                viewModel.isMirrorActive = true
                HapticManager.shared.play(.toggle)
            }
            
            gridButton(
                icon: "doc.on.clipboard.fill", label: L10n.clipboard,
                isActive: viewModel.isClipboardVisible,
                tint: .teal
            ) {
                viewModel.isClipboardVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            ZStack(alignment: .topTrailing) {
                gridButton(
                    icon: "wind", label: L10n.brain,
                    isActive: viewModel.isBrainDumpVisible,
                    tint: .orange
                ) {
                    viewModel.isBrainDumpVisible = true
                    HapticManager.shared.play(.toggle)
                }
                if brainDump.activeCount > 0 {
                    Text("\(brainDump.activeCount)")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(brainDump.urgentCount > 0 ? Color.red : Color.orange))
                        .offset(x: 4, y: -4)
                }
            }
            
            gridButton(
                icon: "speaker.wave.3.fill", label: L10n.volume,
                isActive: viewModel.isVolumeMixerVisible,
                tint: .purple
            ) {
                viewModel.isVolumeMixerVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            // Row 2: Utilities
            gridButton(
                icon: GestureEyeEngine.shared.isActive ? "eye.fill" : "eye.slash",
                label: L10n.eye,
                isActive: GestureEyeEngine.shared.isActive,
                tint: .green
            ) {
                viewModel.isEyeControlVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            // Timer with progress ring
            ZStack {
                gridButton(
                    icon: viewModel.timerActive ? "timer" : "clock",
                    label: viewModel.timerActive ? viewModel.timerDisplay : L10n.timer,
                    isActive: viewModel.timerActive,
                    tint: viewModel.timerActive ? .orange : nil
                ) {
                    if viewModel.timerActive { viewModel.stopTimer() } else { viewModel.startTimer(minutes: nil) }
                    HapticManager.shared.play(.toggle)
                }
                .contextMenu {
                    Button(action: { viewModel.startTimer(minutes: 1) }) {
                        Label("👁️ Eye Rest (1m)", systemImage: "eye.fill")
                    }
                    Button(action: { viewModel.startTimer(minutes: 2) }) {
                        Label("🫁 Breathe (2m)", systemImage: "wind")
                    }
                    Button(action: { viewModel.startTimer(minutes: 5) }) {
                        Label("🧘 Meditate (5m)", systemImage: "figure.mind.and.body")
                    }
                    Divider()
                    Button(action: { viewModel.startTimer(minutes: 10) }) {
                        Label("☕ Coffee (10m)", systemImage: "cup.and.saucer.fill")
                    }
                    Button(action: { viewModel.startTimer(minutes: 15) }) {
                        Label("⚡ Quick Focus (15m)", systemImage: "bolt.fill")
                    }
                    Button(action: { viewModel.startTimer(minutes: 25) }) {
                        Label("🍅 Pomodoro (25m)", systemImage: "leaf.fill")
                    }
                    Button(action: { viewModel.startTimer(minutes: 45) }) {
                        Label("🧠 Deep Work (45m)", systemImage: "brain.head.profile")
                    }
                    Button(action: { viewModel.startTimer(minutes: 60) }) {
                        Label("🏔️ Marathon (60m)", systemImage: "mountain.2.fill")
                    }
                    if viewModel.timerActive {
                        Divider()
                        Button(role: .destructive, action: { viewModel.stopTimer() }) {
                            Label("Stop Timer", systemImage: "xmark.circle")
                        }
                    }
                }
                
                // Progress ring overlay when active
                if viewModel.timerActive {
                    Circle()
                        .trim(from: 0, to: viewModel.timerProgress)
                        .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                        .animation(.linear(duration: 1), value: viewModel.timerProgress)
                }
            }
            
            // Settings
            gridButton(icon: "gearshape.fill", label: L10n.settingsBtn) {
                viewModel.isSettingsVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            // Quick Launch
            gridButton(
                icon: "rocket.fill", label: "Apps",
                isActive: viewModel.isQuickLaunchVisible,
                tint: .pink
            ) {
                viewModel.isQuickLaunchVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            // Swarm
            gridButton(
                icon: "ant.fill", label: "Swarm",
                isActive: viewModel.isSwarmVisible,
                tint: .cyan
            ) {
                viewModel.isSwarmVisible = true
                HapticManager.shared.play(.toggle)
            }
            
            // 🧠 CORTEX Memory
            ZStack(alignment: .topTrailing) {
                gridButton(
                    icon: "brain.fill", label: "CORTEX",
                    isActive: viewModel.isCortexVisible,
                    tint: viewModel.cortex.connectionState == .connected ? .purple : nil
                ) {
                    viewModel.isCortexVisible = true
                    HapticManager.shared.play(.toggle)
                }
                if viewModel.cortex.ghostCount > 0 {
                    Text("\(viewModel.cortex.ghostCount)")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(viewModel.cortex.ghostCount > 5 ? Color.red : Color.purple))
                        .offset(x: 4, y: -4)
                }
            }
            
            // Calendar — premium schedule
            ZStack(alignment: .topTrailing) {
                gridButton(
                    icon: "calendar", label: "Schedule",
                    isActive: viewModel.isCalendarVisible,
                    tint: .blue
                ) {
                    viewModel.isCalendarVisible = true
                    HapticManager.shared.play(.toggle)
                }
                // Urgency badge: next event countdown
                if let next = calendar.nextEvent, next.minutesUntil < 60 {
                    Text(next.minutesUntil < 1 ? "NOW" : "\(next.minutesUntil)m")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(nsColor: next.urgencyColor)))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .padding(.horizontal, DS.Space.xs)
        .padding(.vertical, DS.Space.sm)
    }
    
    /// Grid button with icon + visible label — premium style
    private func gridButton(
        icon: String,
        label: String,
        isActive: Bool = false,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let accentColor = tint ?? (viewModel.isPlaying ? viewModel.albumColor : .white)
        
        return Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isActive ? accentColor : DS.Colors.textTertiary)
                    .shadow(color: isActive ? accentColor.opacity(0.6) : .clear, radius: 6)
                
                Text(label)
                    .font(DS.Fonts.tinyRound)
                    .foregroundColor(isActive ? accentColor.opacity(0.9) : DS.Colors.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DS.Layout.gridButtonH)
            .background(
                ZStack {
                    if isActive {
                        // Active: tinted glow on black
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(Color.black)
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(accentColor.opacity(0.12))
                        // Top-down radial glow
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accentColor.opacity(0.1), .clear],
                                    center: .top,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                    } else {
                        // Inactive: pure black with whisper surface
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(Color.black)
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(
                        isActive ? accentColor.opacity(0.3) : Color.white.opacity(0.04),
                        lineWidth: isActive ? 0.75 : 0.5
                    )
            )
            // Accent bar at bottom when active
            .overlay(alignment: .bottom) {
                if isActive {
                    Capsule()
                        .fill(accentColor.opacity(0.7))
                        .frame(width: 14, height: 2)
                        .offset(y: -3)
                        .shadow(color: accentColor.opacity(0.3), radius: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }
    
    
    // ═══════════════════════════════════════
    // MARK: - Layout
    // ═══════════════════════════════════════
    
    var currentWidth: CGFloat {
        if viewModel.isMirrorActive { return mirrorWidth }
        if viewModel.isClipboardVisible { return clipboardWidth }
        if viewModel.isBrainDumpVisible { return panelWidth }
        if viewModel.isVolumeMixerVisible { return panelWidth }
        if viewModel.isEyeControlVisible { return panelWidth }
        if viewModel.isQuickLaunchVisible { return panelWidth }
        if viewModel.isSwarmVisible { return panelWidth }
        if viewModel.isCortexVisible { return panelWidth }
        if viewModel.isCalendarVisible { return panelWidth }
        if viewModel.isSettingsVisible { return panelWidth }
        if !viewModel.droppedFiles.isEmpty && viewModel.isExpanded { return trayWidth }
        if viewModel.isExpanded { return panelWidth }
        return 0
    }
    
    var currentHeight: CGFloat {
        if viewModel.isMirrorActive { return 230 }
        if viewModel.isClipboardVisible { return 240 }
        if viewModel.isBrainDumpVisible { return 260 }
        if viewModel.isVolumeMixerVisible { return 250 }
        if viewModel.isEyeControlVisible { return 260 }
        if viewModel.isQuickLaunchVisible { return 240 }
        if viewModel.isSwarmVisible { return 280 }
        if viewModel.isCortexVisible { return 300 }
        if viewModel.isCalendarVisible { return 260 }
        if viewModel.isSettingsVisible { return 340 }
        if !viewModel.droppedFiles.isEmpty && viewModel.isExpanded { return 220 }
        if viewModel.isExpanded {
            var h: CGFloat = 200
            if viewModel.showVolumeSlider { h += 24 }
            return h
        }
        return 0
    }
    
    // ═══════════════════════════════════════
    // MARK: - Interaction
    // ═══════════════════════════════════════
    
    func handleHover(_ hovering: Bool) {
        if hovering && !isHovered {
            HapticManager.shared.play(.alignment)
        }
        isHovered = hovering
        hoverTimer?.invalidate()
        
        // No auto-expand on hover — only click toggles (prevents resize loop freeze).
        // Auto-collapse when mouse leaves after a delay.
        if !hovering && isAnyPanelActive {
            let delay: TimeInterval = 5.0
            hoverTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                DispatchQueue.main.async {
                    if !self.isHovered {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            self.collapseAll()
                        }
                    }
                }
            }
        }
    }
    
    func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // 1. Try URL (File on disk) - Using NSURL for NSItemProviderReading conformance
            if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { url, _ in
                    guard let url = url as? URL else { return }
                    
                    // Check if image file for OCR
                    if let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.performOCR(on: image)
                        }
                    } else {
                        // Not an image: Treat as file drop
                        DispatchQueue.main.async {
                            self.addDroppedFile(url)
                        }
                    }
                }
            }
            // 2. Try Image (Direct drag from Browser/Photos)
            else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let image = image as? NSImage {
                        DispatchQueue.main.async {
                            self.performOCR(on: image)
                        }
                    }
                }
            }
            // 3. Try String (Text selection)
            else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text = text {
                        DispatchQueue.main.async {
                            self.copyToClipboard(text)
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func performOCR(on image: NSImage) {
        VisionService.shared.recognizeText(from: image) { text in
            DispatchQueue.main.async {
                if let text = text, !text.isEmpty {
                    self.copyToClipboard(text)
                } else {
                    // Start search or other action if no text?
                    // For now just ignore if image has no text and no URL
                    HapticManager.shared.play(.warning)
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            self.viewModel.showStatus("OCR: Copied (\(text.count) chars)", icon: "doc.text.viewfinder")
        }
    }
    
    private func addDroppedFile(_ url: URL) {
        if !self.viewModel.droppedFiles.contains(where: { $0.absoluteString == url.absoluteString }) {
            self.viewModel.droppedFiles.append(url)
            self.viewModel.isExpanded = true
            HapticManager.shared.play(.drop)
        }
    }
}

