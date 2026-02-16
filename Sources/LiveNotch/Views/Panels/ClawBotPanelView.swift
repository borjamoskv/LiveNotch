import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🐾 ClawBot Panel — Premium ALCOVE AI Chat
// ═══════════════════════════════════════════════════
// Glossy black panel with glassmorphism chips, neon category
// pills, and capsule chat input. Designed from Stitch mockup.

struct ClawBotPanelView: View {
    @ObservedObject var claw: OpenClawBridge
    var onClose: () -> Void
    
    @State private var input = ""
    @FocusState private var isFocused: Bool
    @State private var selectedCategory: TemplateCategory?
    @Namespace private var pillAnimation
    
    // ── Neon Accent Palette ──
    private enum Neon {
        static let pink   = Color(red: 255/255, green: 60/255, blue: 170/255)
        static let blue   = Color(red: 60/255, green: 140/255, blue: 255/255)
        static let yellow = Color(red: 255/255, green: 210/255, blue: 60/255)
        static let purple = Color(red: 160/255, green: 80/255, blue: 255/255)
        static let green  = Color(red: 50/255, green: 215/255, blue: 120/255)
        static let cyan   = Color(red: 0/255, green: 220/255, blue: 240/255)
        static let orange = Color(red: 255/255, green: 140/255, blue: 50/255)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            header
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
            
            Divider()
                .overlay(DS.Colors.strokeHairline)
            
            // ── Category Filter Pills ──
            categoryPills
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            
            // ── Chat History ──
            chatHistory
                .padding(.horizontal, 10)
            
            // ── Command Chips Grid ──
            commandGrid
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            
            Spacer(minLength: 4)
            
            // ── Chat Input Bar ──
            inputBar
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(width: 350)
        .background(
            ZStack {
                // Deep base
                DS.Colors.bgDark
                // Subtle radial glow from top
                RadialGradient(
                    colors: [Neon.blue.opacity(0.04), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DS.Colors.glassBorder.opacity(0.6),
                            DS.Colors.strokeHairline,
                            DS.Colors.glassBorder.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: DS.Colors.shadowDeep, radius: 30, y: 10)
        .shadow(color: DS.Colors.shadowAbyss, radius: 60, y: 20)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Header
    // ═══════════════════════════════════════════════════
    
    private var header: some View {
        HStack(spacing: 6) {
            // Brain icon with glow
            ZStack {
                Circle()
                    .fill(Neon.blue.opacity(0.15))
                    .frame(width: 22, height: 22)
                
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Neon.blue, Neon.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("ClawBot")
                    .font(DS.Fonts.labelSemi)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Text("NEURAL ENGINE V2")
                    .font(DS.Fonts.microMono)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            
            if claw.isProcessing {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
                    .tint(Neon.blue)
            }
            
            Spacer()
            
            // Connection status capsule
            HStack(spacing: 4) {
                Circle()
                    .fill(claw.isConnected ? Neon.green : Color.orange)
                    .frame(width: 5, height: 5)
                    .shadow(color: claw.isConnected ? Neon.green.opacity(0.6) : .clear, radius: 3)
                
                Text(claw.isConnected ? "CONNECTED" : "LOCAL")
                    .font(DS.Fonts.microBold)
                    .foregroundStyle(
                        claw.isConnected
                            ? Neon.green.opacity(0.8)
                            : DS.Colors.textTertiary
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DS.Colors.surfaceCard)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        claw.isConnected ? Neon.green.opacity(0.2) : DS.Colors.strokeFaint,
                        lineWidth: 0.5
                    )
            )
            
            // Close button
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Colors.textMuted)
                    .frame(width: 16, height: 16)
                    .background(DS.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Category Filter Pills
    // ═══════════════════════════════════════════════════
    
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" pill
                categoryPill(label: "All", icon: "sparkles", color: Neon.blue, isSelected: selectedCategory == nil) {
                    withAnimation(DS.NotchSpring.snappy) { selectedCategory = nil }
                }
                
                ForEach(TemplateCategory.allCases, id: \.self) { cat in
                    categoryPill(
                        label: cat.label,
                        icon: cat.icon,
                        color: cat.color,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(DS.NotchSpring.snappy) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
        }
    }
    
    private func categoryPill(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                Text(label)
                    .font(DS.Fonts.tinyBold)
            }
            .foregroundStyle(isSelected ? .white : color.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if isSelected {
                        color.opacity(0.2)
                    } else {
                        DS.Colors.surfaceCard
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? color.opacity(0.5) : DS.Colors.strokeFaint,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.25) : .clear,
                radius: 6
            )
        }
        .buttonStyle(.plain)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Chat History
    // ═══════════════════════════════════════════════════
    
    private var chatHistory: some View {
        Group {
            if !claw.chatHistory.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(claw.chatHistory) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    .frame(minHeight: 30, maxHeight: 90)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.05),
                                .init(color: .white, location: 0.95),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: claw.chatHistory.count) { _, _ in
                        if let last = claw.chatHistory.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func chatBubble(_ msg: OpenClawBridge.ClawResponse) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let action = msg.actionType {
                ZStack {
                    Circle()
                        .fill(actionColor(action).opacity(0.12))
                        .frame(width: 16, height: 16)
                    Image(systemName: actionIcon(action))
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(actionColor(action))
                }
            }
            
            Text(msg.text)
                .font(DS.Fonts.smallRound)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(DS.Colors.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(DS.Colors.strokeHairline, lineWidth: 0.5)
                )
        )
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Command Chips Grid
    // ═══════════════════════════════════════════════════
    
    private var commandGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            let columns = [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ]
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(filteredTemplates) { tpl in
                    commandChip(tpl)
                }
            }
        }
        .frame(maxHeight: 160)
    }
    
    private func commandChip(_ tpl: ClawTemplate) -> some View {
        Button {
            input = tpl.prompt
            sendMessage()
        } label: {
            HStack(spacing: 6) {
                // Icon with glow background
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(tpl.color.opacity(0.1))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: tpl.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tpl.color)
                }
                
                // Label
                Text(tpl.label)
                    .font(DS.Fonts.tinySemi)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    // Glass base
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(DS.Colors.glassLayer1)
                    
                    // Inner highlight (top edge)
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DS.Colors.innerHighlight,
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                tpl.color.opacity(0.25),
                                tpl.color.opacity(0.08),
                                DS.Colors.strokeFaint
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: tpl.color.opacity(0.08), radius: 8)
        }
        .buttonStyle(GlassChipButtonStyle())
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Input Bar
    // ═══════════════════════════════════════════════════
    
    private var inputBar: some View {
        HStack(spacing: 6) {
            // Attachment button
            Button {
                // Future: paste clipboard content
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(DS.Colors.surfaceLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            TextField("Ask ClawBot anything...", text: $input)
                .font(DS.Fonts.bodyRound)
                .foregroundStyle(DS.Colors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { sendMessage() }
                .onChange(of: input) { _, newValue in
                    if newValue.count > 500 {
                        input = String(newValue.prefix(500))
                    }
                }
            
            // Send button
            Button { sendMessage() } label: {
                ZStack {
                    if input.isEmpty && !claw.isProcessing {
                        Circle()
                            .fill(DS.Colors.surfaceLight)
                            .frame(width: 24, height: 24)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Neon.blue, Neon.blue.opacity(0.7)] as [Color],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: Neon.blue.opacity(0.3), radius: 6)
                    }
                    
                    Image(systemName: claw.isProcessing ? "stop.fill" : "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            input.isEmpty && !claw.isProcessing
                                ? DS.Colors.textTertiary
                                : .white
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(input.isEmpty && !claw.isProcessing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(DS.Colors.surfaceCard)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.innerHighlight, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    isFocused
                        ? Neon.blue.opacity(0.4)
                        : DS.Colors.strokeFaint,
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        .shadow(
            color: isFocused ? Neon.blue.opacity(0.15) : .clear,
            radius: 10
        )
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Actions
    // ═══════════════════════════════════════════════════
    
    private func sendMessage() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        Task { await claw.send(text) }
    }
    
    private func actionIcon(_ action: OpenClawBridge.ActionType) -> String {
        switch action {
        case .audioSwitch:  return "airpodspro"
        case .ancToggle:    return "ear.fill"
        case .noteCapture:  return "note.text"
        case .automation:   return "gearshape.2.fill"
        case .query:        return "magnifyingglass"
        case .shellCommand: return "terminal.fill"
        case .fileAction:   return "doc.fill"
        }
    }
    
    private func actionColor(_ action: OpenClawBridge.ActionType) -> Color {
        switch action {
        case .audioSwitch:  return Neon.cyan
        case .ancToggle:    return Neon.purple
        case .noteCapture:  return Neon.yellow
        case .automation:   return Neon.orange
        case .query:        return Neon.blue
        case .shellCommand: return Neon.green
        case .fileAction:   return Neon.cyan
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Template Data Model
    // ═══════════════════════════════════════════════════
    
    private struct ClawTemplate: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let prompt: String
        let color: Color
        let category: TemplateCategory
    }
    
    private enum TemplateCategory: String, CaseIterable {
        case audio       = "Audio"
        case developer   = "Dev"
        case writing     = "Writing"
        case system      = "System"
        case productivity = "Tasks"
        case creative    = "Creative"
        case health      = "Health"
        
        var label: String { rawValue }
        
        var icon: String {
            switch self {
            case .audio:        return "waveform"
            case .developer:    return "chevron.left.forwardslash.chevron.right"
            case .writing:      return "text.cursor"
            case .system:       return "gearshape"
            case .productivity: return "bolt.fill"
            case .creative:     return "paintbrush.fill"
            case .health:       return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .audio:        return Neon.pink
            case .developer:    return Neon.blue
            case .writing:      return Neon.yellow
            case .system:       return Neon.purple
            case .productivity: return Neon.orange
            case .creative:     return Neon.cyan
            case .health:       return Neon.green
            }
        }
    }
    
    private var filteredTemplates: [ClawTemplate] {
        guard let cat = selectedCategory else { return Self.allTemplates }
        return Self.allTemplates.filter { $0.category == cat }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - 40+ Action Templates
    // ═══════════════════════════════════════════════════
    
    private static let allTemplates: [ClawTemplate] = [
        // ── 🎧 Audio ──
        .init(icon: "airpodspro", label: "AirPods → Mac", prompt: "switch AirPods to Mac", color: Neon.cyan, category: .audio),
        .init(icon: "airpodspro", label: "AirPods → Watch", prompt: "switch AirPods to Apple Watch", color: Neon.cyan, category: .audio),
        .init(icon: "ear.fill", label: "ANC On", prompt: "set ANC to active noise cancellation", color: Neon.purple, category: .audio),
        .init(icon: "ear.badge.waveform", label: "Transparency", prompt: "set ANC to transparency mode", color: Neon.purple, category: .audio),
        .init(icon: "speaker.wave.3.fill", label: "Vol 50%", prompt: "set volume to 50 percent", color: Neon.blue, category: .audio),
        .init(icon: "speaker.slash.fill", label: "Mute", prompt: "mute all audio", color: Neon.pink, category: .audio),
        .init(icon: "music.note", label: "Now Playing?", prompt: "what song is currently playing?", color: Neon.pink, category: .audio),
        .init(icon: "waveform", label: "EQ Work", prompt: "switch equalizer to work profile", color: Neon.orange, category: .audio),
        
        // ── 💻 Dev ──
        .init(icon: "terminal.fill", label: "Shell", prompt: "run: ", color: Neon.green, category: .developer),
        .init(icon: "doc.text.magnifyingglass", label: "Explain Code", prompt: "explain this code: ", color: Neon.cyan, category: .developer),
        .init(icon: "ladybug.fill", label: "Debug", prompt: "debug this error: ", color: Neon.pink, category: .developer),
        .init(icon: "arrow.triangle.branch", label: "Git Status", prompt: "run: git status && git log --oneline -5", color: Neon.orange, category: .developer),
        .init(icon: "arrow.up.doc.fill", label: "Git Commit", prompt: "generate commit message for current changes", color: Neon.orange, category: .developer),
        .init(icon: "testtube.2", label: "Gen Tests", prompt: "generate unit tests for: ", color: Neon.purple, category: .developer),
        .init(icon: "arrow.2.squarepath", label: "Refactor", prompt: "refactor this code for readability: ", color: Neon.blue, category: .developer),
        .init(icon: "swift", label: "Swift Build", prompt: "run: cd ~/notch-live && swift build 2>&1 | tail -20", color: Neon.orange, category: .developer),
        
        // ── ✍️ Writing ──
        .init(icon: "textformat.abc", label: "Fix Grammar", prompt: "fix grammar and spelling: ", color: Neon.green, category: .writing),
        .init(icon: "character.book.closed.fill", label: "EN → ES", prompt: "translate to Spanish: ", color: Neon.blue, category: .writing),
        .init(icon: "character.book.closed.fill", label: "ES → EN", prompt: "translate to English: ", color: Neon.blue, category: .writing),
        .init(icon: "text.redaction", label: "Summarize", prompt: "summarize this text concisely: ", color: Neon.purple, category: .writing),
        .init(icon: "text.alignleft", label: "Make Formal", prompt: "rewrite in formal professional tone: ", color: Neon.yellow, category: .writing),
        .init(icon: "text.alignleft", label: "Make Casual", prompt: "rewrite in casual friendly tone: ", color: Neon.pink, category: .writing),
        .init(icon: "text.badge.plus", label: "Expand Idea", prompt: "expand this idea into a detailed paragraph: ", color: Neon.orange, category: .writing),
        .init(icon: "list.bullet", label: "Key Points", prompt: "extract key bullet points from: ", color: Neon.cyan, category: .writing),
        
        // ── ⚙️ System ──
        .init(icon: "moon.stars.fill", label: "Dark Mode", prompt: "toggle dark mode", color: Neon.purple, category: .system),
        .init(icon: "cup.and.saucer.fill", label: "Caffeinate", prompt: "run: caffeinate -dims &", color: Neon.orange, category: .system),
        .init(icon: "trash.fill", label: "Clean Downloads", prompt: "run: find ~/Downloads -mtime +30 -ls", color: Neon.pink, category: .system),
        .init(icon: "externaldrive.fill", label: "Disk Free", prompt: "run: df -h / | tail -1", color: Neon.blue, category: .system),
        .init(icon: "memorychip", label: "RAM/CPU", prompt: "run: top -l 1 | head -10", color: Neon.cyan, category: .system),
        .init(icon: "wifi", label: "Speed Test", prompt: "run: networkQuality -s", color: Neon.green, category: .system),
        .init(icon: "camera.fill", label: "Screenshot", prompt: "run: screencapture -i ~/Desktop/capture.png", color: Neon.yellow, category: .system),
        .init(icon: "arrow.clockwise", label: "Restart Finder", prompt: "run: killall Finder", color: Neon.pink, category: .system),
        
        // ── ⚡ Tasks ──
        .init(icon: "note.text", label: "Quick Note", prompt: "capture note: ", color: Neon.yellow, category: .productivity),
        .init(icon: "checklist", label: "New Task", prompt: "create task: ", color: Neon.orange, category: .productivity),
        .init(icon: "clock.fill", label: "Pomodoro 25m", prompt: "start pomodoro timer 25 minutes", color: Neon.pink, category: .productivity),
        .init(icon: "moon.fill", label: "Focus Mode", prompt: "activate focus mode: mute notifications", color: Neon.purple, category: .productivity),
        .init(icon: "sun.max.fill", label: "Daily Briefing", prompt: "give me today's briefing: calendar, weather, tasks", color: Neon.orange, category: .productivity),
        .init(icon: "bell.slash.fill", label: "DND 1h", prompt: "enable Do Not Disturb for 1 hour", color: Neon.blue, category: .productivity),
        
        // ── 🎨 Creative ──
        .init(icon: "paintbrush.fill", label: "Color Palette", prompt: "generate a color palette inspired by: ", color: Neon.purple, category: .creative),
        .init(icon: "lightbulb.fill", label: "Brainstorm", prompt: "brainstorm 5 creative ideas for: ", color: Neon.yellow, category: .creative),
        .init(icon: "photo.fill", label: "Image Prompt", prompt: "write an image generation prompt for: ", color: Neon.pink, category: .creative),
        .init(icon: "music.quarternote.3", label: "Playlist Mood", prompt: "suggest a playlist for this mood: ", color: Neon.cyan, category: .creative),
        
        // ── 💚 Health ──
        .init(icon: "lungs.fill", label: "Breathe", prompt: "start 1-minute breathing exercise", color: Neon.cyan, category: .health),
        .init(icon: "figure.walk", label: "Steps Today", prompt: "how many steps have I taken today?", color: Neon.green, category: .health),
        .init(icon: "drop.fill", label: "Hydration", prompt: "remind me to drink water every 30 minutes", color: Neon.blue, category: .health),
        .init(icon: "eye.fill", label: "Eye Rest", prompt: "start 20-20-20 eye rest timer", color: Neon.green, category: .health),
    ]
}

// ═══════════════════════════════════════════════════
// MARK: - Glass Chip Button Style
// ═══════════════════════════════════════════════════

private struct GlassChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(DS.NotchSpring.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🐾 Compact ClawBot Wing
// ═══════════════════════════════════════════════════

struct ClawBotWingView: View {
    @ObservedObject var claw: OpenClawBridge
    
    private let neonBlue = Color(red: 60/255, green: 140/255, blue: 255/255)
    private let neonGreen = Color(red: 50/255, green: 215/255, blue: 120/255)
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(claw.isConnected ? neonGreen : Color.orange)
                .frame(width: 4, height: 4)
                .shadow(color: claw.isConnected ? neonGreen.opacity(0.5) : .clear, radius: 2)
            
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 7))
                .foregroundStyle(
                    LinearGradient(
                        colors: [neonBlue, neonBlue.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            if let last = claw.lastResponse {
                Text(last.text.prefix(12))
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
