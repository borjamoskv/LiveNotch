import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - ⚙️ Settings Panel
// ═══════════════════════════════════════════════════
// Extracted from PanelViews.swift

struct SettingsPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @EnvironmentObject var profile: UserProfileManager
    
    // ═══════════════════════════════════════
    // MARK: - Body
    // ═══════════════════════════════════════
    
    var body: some View {
        VStack(spacing: 6) {
            PanelHeader(
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
    
    // ═══════════════════════════════════════
    // MARK: - Helpers
    // ═══════════════════════════════════════
    
    // Computed property to get current profile accent color as Color
    private var profileAccent: Color {
        // Simple mapping, or use Profile manager helper if available
        // For now using the logic from existing codebase which seems to rely on profile.currentProfile.accentColor string
        // But in the original code, `profileAccent` wasn't explicitly defined in the snippet I saw, likely a computed property in NotchView.
        // I will reimplement it locally using `accentColorOptions` logic.
        accentColorOptions.first(where: { $0.name == profile.currentProfile.accentColor })?.color ?? DS.Colors.yinmnBlue
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
    
    // ── Shared row icon + labels ──
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
