import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 📂 Panel Views — Extracted & Enhanced
// ═══════════════════════════════════════════════════

extension NotchView {
    
    // ═══════════════════════════════════════
    // MARK: - Panel Header Helper
    // ═══════════════════════════════════════
    
    func panelHeader(icon: String, iconColor: Color, title: String, trailing: (() -> AnyView)? = nil, onClose: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(DS.Fonts.title)
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.4), radius: 4)
                Text(title)
                    .font(DS.Fonts.labelBold)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            Spacer()
            
            if let trailing = trailing {
                trailing()
            }
            
            Button(action: {
                onClose()
                HapticManager.shared.play(.toggle)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Fonts.title)
                    .foregroundColor(DS.Colors.textMuted)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.Space.section)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Mirror Panel
    // ═══════════════════════════════════════
    
    func mirrorPanel() -> some View {
        VStack(spacing: 8) {
            ZStack {
                CameraPreview(cameraService: cameraService)
                    .frame(width: mirrorWidth - 32, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .stroke(DS.Colors.strokeLight, lineWidth: 0.5)
                    )
                    .shadow(color: DS.Shadow.lg, radius: 10, y: 4)
                
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.isMirrorActive = false
                            HapticManager.shared.play(.toggle)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(DS.Fonts.h3)
                                .foregroundColor(.white.opacity(0.5))
                                .background(Circle().fill(Color.black.opacity(0.4)))
                                .padding(8)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    Spacer()
                }
            }
            
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Image(systemName: "camera.fill")
                    .font(DS.Fonts.tiny)
                Text(L10n.mirror)
                    .font(DS.Fonts.tinySemi)
            }
            .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Clipboard Panel
    // ═══════════════════════════════════════
    
    func clipboardPanel() -> some View {
        VStack(spacing: 8) {
            panelHeader(
                icon: "doc.on.clipboard.fill",
                iconColor: .cyan,
                title: L10n.clipboard,
                trailing: {
                    AnyView(
                        Group {
                            if !clipboard.items.isEmpty {
                                HStack(spacing: 6) {
                                    Text("\(clipboard.items.count)")
                                        .font(DS.Fonts.tinyMono)
                                        .foregroundColor(.cyan.opacity(0.7))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.08))
                                        .clipShape(Capsule())
                                    
                                    Button(action: {
                                        clipboard.clear()
                                        HapticManager.shared.play(.toggle)
                                    }) {
                                        Text("Clear")
                                            .font(DS.Fonts.tinyRound)
                                            .foregroundColor(.white.opacity(0.3))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.05))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    )
                },
                onClose: { viewModel.isClipboardVisible = false }
            )
            
            if clipboard.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 24, weight: .ultraLight)) // unique ultra-light — no token
                        .foregroundColor(.white.opacity(0.1))
                    Text("Clipboard is empty")
                        .font(DS.Fonts.bodyRound)
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(height: 90)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(clipboard.items.prefix(10)) { item in
                            ClipboardItemView(item: item) {
                                clipboard.copyItem(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Tray Panel (Drag & Drop)
    // ═══════════════════════════════════════
    
    func trayPanel() -> some View {
        VStack(spacing: 8) {
            panelHeader(
                icon: "tray.full.fill",
                iconColor: .orange,
                title: L10n.fileTray,
                trailing: {
                    AnyView(
                        HStack(spacing: 6) {
                            Text("\(viewModel.droppedFiles.count) files")
                                .font(DS.Fonts.tinyMono)
                                .foregroundColor(.orange.opacity(0.6))
                            
                            Button(action: {
                                viewModel.droppedFiles.removeAll()
                                HapticManager.shared.play(.toggle)
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(DS.Fonts.body)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    )
                },
                onClose: {
                    viewModel.droppedFiles.removeAll()
                    viewModel.isExpanded = false
                }
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(viewModel.droppedFiles, id: \.absoluteString) { file in
                        VStack(spacing: 4) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                .resizable()
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                            Text(file.lastPathComponent)
                                .font(DS.Fonts.micro)
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            NSWorkspace.shared.open(file)
                        }
                    }
                }
            }
            .frame(maxHeight: 130)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Brain Dump Panel
    // ═══════════════════════════════════════
    
    func brainDumpPanel() -> some View {
        VStack(spacing: 8) {
            // Header
            panelHeader(
                icon: "wind",
                iconColor: .cyan,
                title: L10n.mindflow,
                trailing: {
                    AnyView(
                        HStack(spacing: 6) {
                            if brainDump.activeCount > 0 {
                                Text("\(brainDump.activeCount)")
                                    .font(DS.Fonts.tinyBold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(
                                            brainDump.urgentCount > 0 ?
                                                Color.red.opacity(0.6) :
                                                Color.cyan.opacity(0.4)
                                        )
                                    )
                            }
                            
                            if brainDump.items.contains(where: { $0.isDone }) {
                                Button(action: { brainDump.clearDone() }) {
                                    Text("Clear ✓")
                                        .font(DS.Fonts.tinySemi)
                                        .foregroundColor(.green.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    )
                },
                onClose: { viewModel.isBrainDumpVisible = false }
            )
            
            // Input field
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Fonts.h4)
                    .foregroundColor(.cyan.opacity(0.6))
                
                TextField("What's on your mind...", text: $brainInput)
                    .textFieldStyle(.plain)
                    .font(DS.Fonts.label)
                    .foregroundColor(.white)
                    .onSubmit {
                        brainDump.addItem(brainInput)
                        brainInput = ""
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.cyan.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 14)
            
            // Items list (sorted: urgent first, then by priority, then newest)
            if brainDump.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "brain.filled.head.profile")
                        .font(DS.Fonts.h2)
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan.opacity(0.3), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("Your mind is clear")
                        .font(DS.Fonts.bodyRound)
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(brainDump.sortedItems) { item in
                            brainItemRow(item)
                        }
                    }
                }
                .frame(maxHeight: 140)
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 8)
    }
    
    func brainItemRow(_ item: BrainDumpManager.BrainItem) -> some View {
        HStack(spacing: 8) {
            Button(action: { brainDump.toggleDone(item) }) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(DS.Fonts.title)
                    .foregroundColor(item.isDone ? .green.opacity(0.7) : .white.opacity(0.2))
            }
            .buttonStyle(.plain)
            
            Circle()
                .fill(categoryColor(item.category))
                .frame(width: 5, height: 5)
                .shadow(color: categoryColor(item.category).opacity(0.5), radius: 2)
            
            Text(item.category.emoji)
                .font(DS.Fonts.tiny)
                .grayscale(1.0)
                .opacity(0.8)
            
            Text(item.text)
                .font(.system(size: 10.5, weight: item.priority == 1 ? .bold : .regular))
                .foregroundColor(item.isDone ? .white.opacity(0.2) : .white.opacity(0.8))
                .strikethrough(item.isDone)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.timeAgo)
                .font(DS.Fonts.tiny)
                .foregroundColor(.white.opacity(0.2))
            
            Button(action: { brainDump.removeItem(item) }) {
                Image(systemName: "xmark")
                    .font(DS.Fonts.microBold)
                    .foregroundColor(.white.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            item.priority == 1 ? Color.red.opacity(0.06) : Color.white.opacity(0.02)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
        )
    }
    
    func categoryColor(_ category: BrainDumpManager.Category) -> Color {
        switch category {
        case .work: return .blue
        case .dev: return .cyan
        case .personal: return .green
        case .health: return .orange
        case .idea: return .purple
        case .reminder: return .yellow
        case .shopping: return .teal
        case .urgent: return .red
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Volume Mixer Panel
    // ═══════════════════════════════════════
    
    func volumeMixerPanel() -> some View {
        VStack(spacing: 8) {
            panelHeader(
                icon: "speaker.wave.3.fill",
                iconColor: .blue,
                title: L10n.volumeMixer,
                trailing: {
                    AnyView(
                        Text("\(mixer.audioApps.count) apps")
                            .font(DS.Fonts.tinyMono)
                            .foregroundColor(.white.opacity(0.3))
                    )
                },
                onClose: { viewModel.isVolumeMixerVisible = false }
            )
            
            if mixer.audioApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 24, weight: .ultraLight)) // unique ultra-light — no token
                        .foregroundColor(.white.opacity(0.12))
                    Text("No audio apps running")
                        .font(DS.Fonts.body)
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(mixer.audioApps) { app in
                            mixerAppRow(app)
                        }
                    }
                }
                .frame(maxHeight: 160)
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 8)
    }
    
    func mixerAppRow(_ app: PerAppVolumeMixer.AppAudio) -> some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .shadow(color: DS.Shadow.md, radius: 2, y: 1)
            } else {
                Image(systemName: "app.fill")
                    .font(DS.Fonts.h3)
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 22, height: 22)
            }
            
            Text(app.name)
                .font(DS.Fonts.body)
                .foregroundColor(.white.opacity(0.65))
                .frame(width: 65, alignment: .leading)
                .lineLimit(1)
            
            NotchVolumeSlider(
                volume: Binding(
                    get: { (app.isMuted ? 0 : app.volume) * 100 },
                    set: { newValue in
                        mixer.setVolume(for: app.id, volume: Float(newValue / 100))
                    }
                ),
                color: app.isMuted ? .gray : .blue
            )
            .frame(maxWidth: .infinity)
            
            Text("\(Int((app.isMuted ? 0 : app.volume) * 100))%")
                .font(DS.Fonts.tinyMono)
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 30)
            
            Button(action: {
                mixer.toggleMute(for: app.id)
            }) {
                Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(DS.Fonts.small)
                    .foregroundColor(app.isMuted ? .red.opacity(0.6) : .white.opacity(0.35))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.Colors.surfaceFaint)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.strokeFaint, lineWidth: 0.5)
        )
    }
    
    // ═══════════════════════════════════════
    // MARK: - Settings Panel
    // ═══════════════════════════════════════
    
    func settingsPanel() -> some View {
        VStack(spacing: 6) {
            panelHeader(
                icon: "gearshape.fill",
                iconColor: DS.Colors.yinmnBlue,
                title: L10n.settings,
                onClose: { viewModel.isSettingsVisible = false }
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    
                    // ═══ ACCENT COLOR ═══
                    VStack(spacing: 0) {
                        settingsSection("ACCENT COLOR", color: DS.Colors.yinmnBlue)
                        
                        // Color grid
                        LazyVGrid(columns: [GridItem](repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                            ForEach(accentColorOptions, id: \.name) { option in
                                Button(action: {
                                    profile.updateAccentColor(option.name)
                                    HapticManager.shared.play(.subtle)
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 28, height: 28)
                                            .shadow(color: option.color.opacity(0.4), radius: 4)
                                        
                                        Circle()
                                            .stroke(
                                                profile.currentProfile.accentColor == option.name
                                                    ? Color.white.opacity(0.8)
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                            .frame(width: 32, height: 32)
                                        
                                        if profile.currentProfile.accentColor == option.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .heavy))
                                                .foregroundColor(.white)
                                                .shadow(color: .black.opacity(0.5), radius: 2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, 8)
                        
                        // Current accent name
                        HStack {
                            Spacer()
                            Text(accentColorDisplayName)
                                .font(DS.Fonts.microMono)
                                .foregroundColor(profileAccent.opacity(0.6))
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.bottom, 6)
                    }
                    .settingsCard(glassEnabled: false)
                    
                    // ═══ APPEARANCE ═══
                    VStack(spacing: 0) {
                        settingsSection(L10n.appearance, color: .cyan)
                        
                        settingsToggleRow(
                            icon: "eye.fill",
                            iconColor: .green,
                            label: L10n.eyeControlLabel,
                            sublabel: L10n.eyeControlSub,
                            isOn: Binding(
                                get: { GestureEyeEngine.shared.isEnabled },
                                set: { newVal in
                                    GestureEyeEngine.shared.isEnabled = newVal
                                    if newVal { GestureEyeEngine.shared.activate() }
                                    else { GestureEyeEngine.shared.deactivate() }
                                }
                            )
                        )
                        
                        settingsDivider()
                        
                        settingsToggleRow(
                            icon: "paintpalette.fill",
                            iconColor: .indigo,
                            label: "Chameleon",
                            sublabel: "Adapt to active app",
                            isOn: Binding(
                                get: { NervousSystem.shared.chameleonEnabled },
                                set: { NervousSystem.shared.chameleonEnabled = $0 }
                            )
                        )
                    }
                    .settingsCard(glassEnabled: false)
                    
                    // ═══ BEHAVIOR ═══
                    VStack(spacing: 0) {
                        settingsSection(L10n.behavior, color: .orange)
                        
                        settingsToggleRow(
                            icon: "hand.tap.fill",
                            iconColor: .orange,
                            label: L10n.hapticFeedback,
                            sublabel: L10n.hapticSub,
                            isOn: Binding(
                                get: { HapticManager.shared.isEnabled },
                                set: { HapticManager.shared.isEnabled = $0 }
                            )
                        )
                        
                        settingsDivider()
                        
                        settingsActionRow(
                            icon: "arrow.counterclockwise",
                            iconColor: .yellow,
                            label: L10n.recalibrateEyes,
                            sublabel: L10n.recalibrateEyesSub
                        ) {
                            GestureEyeEngine.shared.deactivate()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                GestureEyeEngine.shared.activate()
                            }
                            HapticManager.shared.play(.toggle)
                        }
                    }
                    .settingsCard(glassEnabled: false)
                    
                    // ═══ AI ASSISTANT ═══
                    VStack(spacing: 0) {
                        settingsSection(L10n.aiAssistant, color: .purple)
                        
                        settingsToggleRow(
                            icon: "sparkles",
                            iconColor: .purple,
                            label: "Naroa",
                            sublabel: "Neural Engine (Swarm)",
                            isOn: .constant(true)
                        )
                    }
                    .settingsCard(glassEnabled: false)
                    
                    // ═══ ABOUT ═══
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            // App icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [DS.Colors.yinmnBlue, DS.Colors.kleinBlue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .shadow(color: DS.Colors.yinmnBlue.opacity(0.3), radius: 6, y: 3)
                                
                                Image(systemName: "sparkle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NOTCH//WINGS")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .tracking(1)
                                
                                Text("v1.1 · Build 2026.02")
                                    .font(DS.Fonts.microMono)
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            
                            Spacer()
                            
                            Button(action: { NSApp.terminate(nil) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "power")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(L10n.quit)
                                        .font(DS.Fonts.tinyBold)
                                }
                                .foregroundColor(.red.opacity(0.5))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.1), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, 8)
                    }
                    .settingsCard(glassEnabled: false)
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // Accent color options for the picker
    private var accentColorOptions: [(name: String, color: Color)] {
        [
            ("white", .white),
            ("blue", .blue),
            ("purple", .purple),
            ("indigo", .indigo),
            ("green", .green),
            ("orange", .orange),
            ("red", .red),
            ("yinmn", DS.Colors.yinmnBlue),
            ("klein", DS.Colors.kleinBlue),
        ]
    }
    
    private var accentColorDisplayName: String {
        switch profile.currentProfile.accentColor {
        case "white": return "Titanium White"
        case "blue": return "Electric Blue"
        case "purple": return "Deep Purple"
        case "indigo": return "Indigo Night"
        case "green": return "Matrix Green"
        case "orange": return "Solar Orange"
        case "red": return "Signal Red"
        case "yinmn": return "YInMn Blue"
        case "klein": return "Klein IKB"
        default: return "Custom"
        }
    }
    
    private func settingsSection(_ title: String, color: Color = DS.Colors.textGhost) -> some View {
        HStack {
            Text(title)
                .font(DS.Fonts.tinyMono)
                .foregroundColor(color.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xxs)
    }
    
    private func settingsDivider() -> some View {
        Rectangle()
            .fill(DS.Colors.surfaceCard)
            .frame(height: 0.5)
            .padding(.leading, 34)
    }
}

// ═══════════════════════════════════════
// MARK: - Settings Card Modifier
// ═══════════════════════════════════════

struct SettingsCardModifier: ViewModifier {
    let glassEnabled: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), glassEnabled {
            content
                .glassEffect(.clear, in: .rect(cornerRadius: DS.Radius.md))
                .padding(.horizontal, DS.Space.xxl)
        } else {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(Color.black)
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
                .padding(.horizontal, DS.Space.xxl)
        }
    }
}

extension View {
    func settingsCard(glassEnabled: Bool = false) -> some View {
        modifier(SettingsCardModifier(glassEnabled: glassEnabled))
    }
}

extension NotchView {
    
    // ── Shared row icon + labels (used by toggle & action rows) ──
    @ViewBuilder
    private func settingsRowContent(icon: String, iconColor: Color, label: String, sublabel: String) -> some View {
        Image(systemName: icon)
            .font(DS.Fonts.body)
            .foregroundColor(iconColor)
            .frame(width: 16)
        
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(DS.Fonts.bodySemi)
                .foregroundColor(.white.opacity(0.8))
            Text(sublabel)
                .font(DS.Fonts.micro)
                .foregroundColor(DS.Colors.textFaint)
        }
    }
    
    private func settingsToggleRow(
        icon: String,
        iconColor: Color,
        label: String,
        sublabel: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: DS.Space.md) {
            settingsRowContent(icon: icon, iconColor: iconColor, label: label, sublabel: sublabel)
            
            Spacer()
            
            // Mini toggle
            Button(action: {
                isOn.wrappedValue.toggle()
                HapticManager.shared.play(.subtle)
            }) {
                Capsule()
                    .fill(isOn.wrappedValue ? iconColor.opacity(0.3) : DS.Colors.textInvisible)
                    .frame(width: 28, height: 16)
                    .overlay(
                        Circle()
                            .fill(isOn.wrappedValue ? iconColor : DS.Colors.textMuted)
                            .frame(width: 12, height: 12)
                            .offset(x: isOn.wrappedValue ? 6 : -6),
                        alignment: .center
                    )
                    .animation(DS.Anim.springFast, value: isOn.wrappedValue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 5)
    }
    
    private func settingsActionRow(
        icon: String,
        iconColor: Color,
        label: String,
        sublabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Space.md) {
                settingsRowContent(icon: icon, iconColor: iconColor, label: label, sublabel: sublabel)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(DS.Fonts.tinyBold)
                    .foregroundColor(DS.Colors.textDim)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Eye Control Panel (Premium)
    // ═══════════════════════════════════════
    
    func eyeControlPanel() -> some View {
        let engine = GestureEyeEngine.shared
        
        return VStack(spacing: 8) {
            panelHeader(
                icon: "eye.fill",
                iconColor: engine.isActive ? .green : .gray,
                title: L10n.eyeControl,
                trailing: {
                    AnyView(
                        HStack(spacing: 4) {
                            if engine.isActive && engine.faceDetected {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text("Tracking")
                                    .font(DS.Fonts.tinySemi)
                                    .foregroundColor(.green.opacity(0.8))
                            } else if engine.isActive {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 5, height: 5)
                                Text("No face")
                                    .font(DS.Fonts.tiny)
                                    .foregroundColor(.orange.opacity(0.7))
                            }
                        }
                    )
                },
                onClose: { viewModel.isEyeControlVisible = false }
            )
            
            // ── Master Toggle ──
            HStack {
                Image(systemName: engine.isEnabled ? "eye.fill" : "eye.slash")
                    .font(DS.Fonts.body)
                    .foregroundColor(engine.isEnabled ? .green : .gray)
                    .shadow(color: engine.isEnabled ? .green.opacity(0.3) : .clear, radius: 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Eye Gestures")
                        .font(DS.Fonts.bodySemi)
                        .foregroundColor(.white.opacity(0.8))
                    if engine.isActive {
                        Text(engine.isCalibrated ? "Calibrated · \(engine.gestureCount) gestures" : "Calibrating…")
                            .font(DS.Fonts.microMono)
                            .foregroundColor(engine.isCalibrated ? .white.opacity(0.2) : .orange.opacity(0.5))
                    } else {
                        Text("Camera off")
                            .font(DS.Fonts.microMono)
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if engine.isEnabled {
                        engine.isEnabled = false
                        engine.deactivate()
                    } else {
                        engine.isEnabled = true
                        engine.activate()
                    }
                    HapticManager.shared.play(.toggle)
                }) {
                    Text(engine.isEnabled ? "ON" : "OFF")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(engine.isEnabled ? .green : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(engine.isEnabled ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .stroke(engine.isEnabled ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            
            // ── Calibration progress (when calibrating) ──
            if engine.isActive && !engine.isCalibrated {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        ProgressView(value: engine.calibrationProgress)
                            .progressViewStyle(.linear)
                            .tint(.cyan)
                        Text("\(Int(engine.calibrationProgress * 100))%")
                            .font(DS.Fonts.microBold)
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                    Text("Look at the camera with both eyes open")
                        .font(DS.Fonts.micro)
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .padding(.horizontal, 14)
            }
            
            // ── Eye Visualizer (when active and calibrated) ──
            if engine.isActive && engine.isCalibrated {
                HStack(spacing: 16) {
                    // Left Eye
                    eyeGraphic(
                        label: "LEFT",
                        ear: engine.visibleLeftEAR,
                        isClosed: engine.visibleIsLeftClosed,
                        color: .cyan
                    )
                    
                    // Center: last gesture or cooldown
                    ZStack {
                        // Cooldown ring
                        if engine.cooldownRemaining > 0 {
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: engine.cooldownRemaining / engine.sensitivity.cooldown)
                                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        VStack(spacing: 2) {
                            if engine.lastGesture != .none {
                                Image(systemName: gestureIcon(engine.lastGesture))
                                    .font(DS.Fonts.h3)
                                    .foregroundColor(gestureColor(engine.lastGesture))
                                    .shadow(color: gestureColor(engine.lastGesture).opacity(0.6), radius: 6)
                                    .transition(.scale.combined(with: .opacity))
                                
                                Text(gestureLabel(engine.lastGesture))
                                    .font(DS.Fonts.microBold)
                                    .foregroundColor(gestureColor(engine.lastGesture).opacity(0.8))
                                    .transition(.opacity)
                            } else if engine.faceDetected {
                                Image(systemName: "face.smiling")
                                    .font(DS.Fonts.h4)
                                    .foregroundColor(.white.opacity(0.15))
                                Text("Ready")
                                    .font(DS.Fonts.micro)
                                    .foregroundColor(.white.opacity(0.2))
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(DS.Fonts.h4)
                                    .foregroundColor(.white.opacity(0.1))
                                Text("Searching")
                                    .font(DS.Fonts.micro)
                                    .foregroundColor(.white.opacity(0.15))
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.lastGesture)
                    
                    // Right Eye
                    eyeGraphic(
                        label: "RIGHT",
                        ear: engine.visibleRightEAR,
                        isClosed: engine.visibleIsRightClosed,
                        color: .purple
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .padding(.horizontal, 14)
            }
            
            // ── Sensitivity Selector ──
            if engine.isActive {
                HStack(spacing: 0) {
                    ForEach(GestureEyeEngine.Sensitivity.allCases, id: \.rawValue) { mode in
                        Button(action: {
                            engine.sensitivity = mode
                            HapticManager.shared.play(.subtle)
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 8, weight: engine.sensitivity == mode ? .heavy : .medium)) // dynamic weight — no token
                                .foregroundColor(engine.sensitivity == mode ? .cyan : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    engine.sensitivity == mode
                                    ? Color.cyan.opacity(0.1)
                                    : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.03))
                .clipShape(Capsule())
                .padding(.horizontal, 14)
            }
            
            // ── Separator ──
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
            
            // ── Gesture Reference (context-aware) ──
            VStack(spacing: 6) {
                // Music mode
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.cyan.opacity(0.6))
                    Text("MUSIC MODE")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.cyan.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                
                gestureRow(icon: "forward.fill", gesture: "Right wink 😉", action: "Next track", color: .cyan)
                gestureRow(icon: "backward.fill", gesture: "Left wink 😉", action: "Prev track", color: .cyan)
                gestureRow(icon: "pause.fill", gesture: "Slow blink 😌", action: "Play / Pause", color: .purple)
                
                // AI mode
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.purple.opacity(0.6))
                    Text("AI MODE")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.purple.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                
                gestureRow(icon: "sparkles", gesture: "Slow blink 😌", action: "Toggle AI bar", color: .purple)
                gestureRow(icon: "doc.on.clipboard", gesture: "Right wink 😉", action: "Clipboard → Kimi", color: .purple)
                gestureRow(icon: "rectangle.expand.vertical", gesture: "Left wink 😉", action: "Expand / Collapse", color: .indigo)
            }
            .padding(.horizontal, 14)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // ── Eye graphic (stylized eye indicator with EAR bar) ──
    private func eyeGraphic(label: String, ear: Double, isClosed: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            // Eye shape with glow ring
            ZStack {
                // Subtle outer glow
                Ellipse()
                    .fill(color.opacity(isClosed ? 0.15 : 0.05))
                    .frame(width: 40, height: 24)
                    .blur(radius: 4)
                
                // Eye outline
                Ellipse()
                    .stroke(color.opacity(isClosed ? 0.6 : 0.3), lineWidth: 1)
                    .frame(width: 32, height: isClosed ? 4 : 18)
                    .animation(DS.Spring.snap, value: isClosed)
                
                // Iris (when open)
                if !isClosed {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color, color.opacity(0.4)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 5
                            )
                        )
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
                
                // Closed line
                if isClosed {
                    Capsule()
                        .fill(color.opacity(0.5))
                        .frame(width: 24, height: 2)
                }
            }
            .frame(width: 36, height: 22)
            
            // EAR level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(isClosed ? color : color.opacity(0.4))
                        .frame(width: max(2, geo.size.width * CGFloat(min(ear / 0.5, 1.0))))
                }
            }
            .frame(width: 36, height: 3)
            .animation(DS.Spring.micro, value: ear)
            
            // Label + EAR value
            VStack(spacing: 1) {
                Text(label)
                    .font(DS.Fonts.microBold)
                    .foregroundColor(.white.opacity(0.3))
                Text(String(format: "%.2f", ear))
                    .font(DS.Fonts.microMono)
                    .foregroundColor(isClosed ? color.opacity(0.8) : .white.opacity(0.25))
            }
        }
    }
    
    // ── Gesture info helpers ──
    private func gestureIcon(_ gesture: FaceGesture) -> String {
        switch gesture {
        case .rightWink: return "forward.fill"
        case .leftWink: return "backward.fill"
        case .slowBlink: return "pause.fill"
        case .longBlink: return "brain.head.profile"
        case .handPinch: return "hand.tap.fill"
        case .handSwipeLeft: return "hand.point.left.fill"
        case .handSwipeRight: return "hand.point.right.fill"
        case .none: return "circle"
        }
    }
    
    private func gestureColor(_ gesture: FaceGesture) -> Color {
        switch gesture {
        case .rightWink: return .cyan
        case .leftWink: return .cyan
        case .slowBlink: return .purple
        case .longBlink: return .pink // Naroa color
        case .handPinch: return .orange
        case .handSwipeLeft: return .yellow
        case .handSwipeRight: return .yellow
        case .none: return .white
        }
    }
    
    private func gestureLabel(_ gesture: FaceGesture) -> String {
        switch gesture {
        case .rightWink: return "NEXT ⏭"
        case .leftWink: return "PREV ⏮"
        case .slowBlink: return "PAUSE ⏸"
        case .longBlink: return "SUMMON 🧠"
        case .handPinch: return "TAP ✋"
        case .handSwipeLeft: return "BACK 👈"
        case .handSwipeRight: return "SKIP 👉"
        case .none: return ""
        }
    }
    
    private func gestureRow(icon: String, gesture: String, action: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DS.Fonts.tinyBold)
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)
            
            Text(gesture)
                .font(DS.Fonts.bodySemi)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(action)
                .font(DS.Fonts.small)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
