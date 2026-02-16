import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎧 Ecosystem Hub (GOD MODE — Negro + Neon)
// ═══════════════════════════════════════════════════

struct EcosystemHubView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var ecosystem = EcosystemBridge.shared
    @ObservedObject var hp = HeadphoneController.shared
    
    var body: some View {
        VStack(spacing: 10) {
            header
            batteryStrip
            div
            ancStrip
            div
            featuresStrip
            div
            intelStrip
            div
            routingStrip
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 400)
    }
    
    // ─── Header ───
    
    private var header: some View {
        HStack {
            Label("ECOSYSTEM", systemImage: "applelogo")
                .font(DS.Fonts.smallBold)
                .foregroundStyle(DS.Colors.textSecondary)
                .tracking(1)
            Spacer()
            if hp.isConnected {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text(hp.deviceName).lineLimit(1)
                }
                .font(DS.Fonts.microBold).foregroundStyle(.green)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.green.opacity(0.08)))
            } else {
                Text("—").font(DS.Fonts.microBold).foregroundStyle(DS.Colors.textMuted)
            }
        }
    }
    
    // ─── Battery ───
    
    private var batteryStrip: some View {
        HStack(spacing: 12) {
            VStack(spacing: 3) {
                ZStack {
                    arcRing(Double(max(0, hp.batteryCase)) / 100, .gray.opacity(0.5), 0)
                    arcRing(Double(max(0, hp.batteryLeft)) / 100, .green, 5)
                    arcRing(Double(max(0, hp.batteryRight)) / 100, .cyan, 10)
                    Image(systemName: "airpods.pro").font(.system(size: 13)).foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)
                HStack(spacing: 3) {
                    batLabel("L", hp.batteryLeft, .green)
                    batLabel("R", hp.batteryRight, .cyan)
                }
                Text("Case \(max(0, hp.batteryCase))%").font(DS.Fonts.micro).foregroundStyle(DS.Colors.textMuted)
            }
            
            if let w = ecosystem.accessories.first(where: { $0.type == .watch }) {
                ring("applewatch", Double(w.batteryLeft) / 100, .orange, "Watch")
            }
            ring("iphone.gen3", 0.85, .blue, "iPhone")
            if let m = ecosystem.accessories.first(where: { $0.type == .mac }) {
                ring("macbook", Double(m.batteryLeft) / 100, .purple, "Mac")
            }
        }
        .padding(.vertical, 4)
    }
    
    // ─── ANC ───
    
    private var ancStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                secHead("NOISE CONTROL", "⌘⇧A")
                Spacer()
                Button {
                    hp.toggleAutoANC()
                    HapticManager.shared.play(.subtle)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: hp.autoANC ? "brain.fill" : "hand.raised.fill")
                            .font(.system(size: 8))
                        Text(hp.autoANC ? "AUTO" : "MANUAL")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(hp.autoANC ? .cyan : .white.opacity(0.4))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(hp.autoANC ? Color.cyan.opacity(0.1) : Color.white.opacity(0.03)))
                    .overlay(Capsule().stroke(hp.autoANC ? Color.cyan.opacity(0.3) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 5) {
                ForEach(HeadphoneController.ANCMode.allCases, id: \.self) { mode in
                    ancPill(mode)
                }
            }
            
            if hp.autoANC, let reason = hp.lastAutoReason {
                Text(reason)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
    
    // ─── Features ───
    
    private var featuresStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            secHead("AUDIO", nil)
            HStack(spacing: 5) {
                feat("ear.and.waveform", "Spatial", "⌘⇧S", hp.spatialAudio, .cyan) { hp.toggleSpatialAudio() }
                feat("person.head.scanning", "Track", nil, hp.headTracking && hp.spatialAudio, .cyan.opacity(0.6), off: !hp.spatialAudio) { hp.toggleHeadTracking() }
                feat("slider.horizontal.3", "EQ", nil, hp.adaptiveEQ, .orange) { hp.toggleAdaptiveEQ() }
                feat("person.wave.2", "Boost", "⌘⇧Q", hp.conversationBoost, .green) { hp.toggleConversationBoost() }
            }
        }
    }
    
    // ─── Intelligence Log ───
    
    private var intelStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            secHead("INTELLIGENCE", nil)
            if hp.intelligenceLog.isEmpty {
                Text("No events yet")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textDim)
            } else {
                ForEach(hp.intelligenceLog.prefix(3)) { event in
                    HStack(spacing: 4) {
                        Text(event.icon).font(.system(size: 9))
                        Text(event.message)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(event.color.opacity(0.8))
                            .lineLimit(1)
                        Spacer()
                        Text(timeAgo(event.time))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(DS.Colors.textDim)
                    }
                }
            }
        }
    }
    
    // ─── Routing ───
    
    private var routingStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            secHead("ROUTING", nil)
            HStack(spacing: 5) {
                routeBtn(.mac); routeBtn(.iphone); routeBtn(.airpods)
            }
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Atoms
    // ═══════════════════════════════════════════════════
    
    private var div: some View { Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5) }
    
    @ViewBuilder
    private func secHead(_ t: String, _ shortcut: String?) -> some View {
        HStack {
            Text(t).font(DS.Fonts.microBold).foregroundStyle(DS.Colors.textGhost).tracking(0.5)
            Spacer()
            if let s = shortcut {
                Text(s).font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Colors.textDim)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.03)))
            }
        }
    }
    
    private func batLabel(_ s: String, _ v: Int, _ c: Color) -> some View {
        HStack(spacing: 1) {
            Text(s).font(DS.Fonts.micro).foregroundStyle(c.opacity(0.5))
            Text("\(max(0, v))%").font(DS.Fonts.microBold).foregroundStyle(c)
        }
    }
    
    private func arcRing(_ pct: Double, _ c: Color, _ pad: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.04), lineWidth: 2).padding(pad)
            Circle().trim(from: 0, to: pct)
                .stroke(c, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: c.opacity(0.3), radius: 2)
                .padding(pad)
        }
    }
    
    private func ring(_ icon: String, _ lv: Double, _ c: Color, _ name: String) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.05), lineWidth: 2.5)
                Circle().trim(from: 0, to: lv)
                    .stroke(c, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: c.opacity(0.3), radius: 3)
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }.frame(width: 36, height: 36)
            Text("\(Int(lv * 100))%").font(DS.Fonts.microBold).foregroundStyle(c)
            Text(name).font(DS.Fonts.micro).foregroundStyle(DS.Colors.textMuted)
        }
    }
    
    private func ancPill(_ mode: HeadphoneController.ANCMode) -> some View {
        let on = hp.ancMode == mode
        return Button {
            hp.setANC(mode)
            HapticManager.shared.play(.subtle)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: mode.icon).font(.system(size: 11, weight: .medium))
                Text(mode.short).font(DS.Fonts.micro)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(on ? mode.neon.opacity(0.1) : Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(on ? mode.neon.opacity(0.35) : .clear, lineWidth: 0.5))
            .foregroundStyle(on ? .white : .white.opacity(0.3))
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func feat(_ icon: String, _ label: String, _ sc: String?, _ on: Bool, _ accent: Color, off: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            guard !off else { return }
            action(); HapticManager.shared.play(.toggle)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(on ? accent : .white.opacity(0.2))
                Text(label).font(DS.Fonts.micro)
                if let s = sc {
                    Text(s).font(.system(size: 6, weight: .medium, design: .monospaced)).foregroundStyle(DS.Colors.textDim)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(on ? accent.opacity(0.06) : Color.white.opacity(0.015)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(on ? accent.opacity(0.2) : Color.white.opacity(0.02), lineWidth: 0.5))
            .foregroundStyle(on ? .white : .white.opacity(off ? 0.12 : 0.35))
            .opacity(off ? 0.5 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func routeBtn(_ device: EcosystemBridge.AudioDevice) -> some View {
        let on = ecosystem.activeAudioDevice == device
        let ic: String = {
            switch device {
            case .mac: return "macbook"; case .iphone: return "iphone"
            case .airpods: return "airpods.pro"; case .watch: return "applewatch"; case .none: return "speaker.slash"
            }
        }()
        let nm: String = {
            switch device {
            case .mac: return "Mac"; case .iphone: return "iPhone"; case .airpods: return "AirPods"
            case .watch: return "Watch"; case .none: return "None"
            }
        }()
        return Button {
            ecosystem.switchAudio(to: device); HapticManager.shared.play(.alignment)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: ic).font(.system(size: 9))
                if on { Text(nm).font(DS.Fonts.microBold).transition(.scale.combined(with: .opacity)) }
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Capsule().fill(on ? Color.green.opacity(0.08) : Color.white.opacity(0.02)))
            .foregroundStyle(on ? .green : .white.opacity(0.25))
            .overlay(Capsule().stroke(on ? Color.green.opacity(0.15) : .clear, lineWidth: 0.5))
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.3), value: on)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m"
    }
}
