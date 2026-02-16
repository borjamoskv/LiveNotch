import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - ⚡ Script Drop Panel View — Premium Terminal
// ═══════════════════════════════════════════════════
// Shows when a script is dropped on the notch.
// Features:
//   • Live stdout/stderr streaming in mini-terminal
//   • Animated execution state (pulse, spinner, result)
//   • Script info header with type icon + color
//   • Kill button during execution
//   • History sidebar with favorites + re-run
//   • Premium Industrial Noir aesthetic

extension NotchView {
    
    // ═══════════════════════════════════════
    // MARK: - Script Drop Panel (Main)
    // ═══════════════════════════════════════
    
    var scriptDrop: ScriptDropService { viewModel.scriptDrop }
    
    func scriptDropPanel() -> some View {
        VStack(spacing: 8) {
            // Header
            PanelHeader(
                icon: scriptDrop.stateIcon,
                iconColor: scriptDrop.stateColor,
                title: "SCRIPT DROP",
                trailing: {
                    AnyView(
                        HStack(spacing: 8) {
                            // Elapsed time
                            if scriptDrop.state == .running || scriptDrop.state == .success || scriptDrop.state != .idle {
                                Text(scriptDrop.elapsedDisplay)
                                    .font(DS.Fonts.tinyMono)
                                    .foregroundColor(scriptDrop.stateColor.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(scriptDrop.stateColor.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            
                            // History count
                            if !scriptDrop.history.isEmpty {
                                Text("\(scriptDrop.history.count)")
                                    .font(DS.Fonts.tinyMono)
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(Capsule())
                            }
                        }
                    )
                },
                onClose: {
                    withAnimation(DS.Anim.springStd) {
                        viewModel.isScriptDropVisible = false
                    }
                    HapticManager.shared.play(.collapse)
                }
            )
            
            // ── Content based on state ──
            switch scriptDrop.state {
            case .idle:
                scriptDropIdleView()
            case .confirming:
                scriptDropConfirmView()
            case .running:
                scriptDropTerminalView()
            case .success, .failed, .killed:
                scriptDropTerminalView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Idle State (Drop Zone + History)
    // ═══════════════════════════════════════
    
    private func scriptDropIdleView() -> some View {
        VStack(spacing: 10) {
            // Drop target
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundColor(scriptDrop.isDropHovering ? .cyan.opacity(0.6) : .white.opacity(0.1))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.6), .cyan.opacity(0.4)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        
                        Text("Drop a script here")
                            .font(DS.Fonts.bodyRound)
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(".sh .py .js .rb .swift .scpt .zsh")
                            .font(DS.Fonts.microMono)
                            .foregroundColor(.white.opacity(0.15))
                    }
                }
                .frame(height: 80)
                .scaleEffect(scriptDrop.isDropHovering ? 1.03 : 1.0)
                .animation(DS.Anim.springSnap, value: scriptDrop.isDropHovering)
            }
            
            // Favorites + Recent History
            if !scriptDrop.history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // Favorites first
                    if !scriptDrop.favorites.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(DS.Fonts.micro)
                                .foregroundColor(.yellow.opacity(0.5))
                            Text("FAVORITES")
                                .font(DS.Fonts.microBold)
                                .foregroundColor(.white.opacity(0.25))
                        }
                        
                        ForEach(scriptDrop.favorites.prefix(5)) { record in
                            scriptHistoryRow(record)
                        }
                    }
                    
                    // Recent
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(DS.Fonts.micro)
                            .foregroundColor(.white.opacity(0.2))
                        Text("RECENT")
                            .font(DS.Fonts.microBold)
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(.top, scriptDrop.favorites.isEmpty ? 0 : 4)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(scriptDrop.recentScripts) { record in
                                scriptHistoryRow(record)
                            }
                        }
                    }
                    .frame(maxHeight: 80)
                }
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Confirm Execution Gate
    // ═══════════════════════════════════════
    
    private func scriptDropConfirmView() -> some View {
        VStack(spacing: 10) {
            // Script info card
            if let url = scriptDrop.pendingScript, let type = scriptDrop.pendingScriptType {
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(type.color)
                        .frame(width: 36, height: 36)
                        .background(type.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .shadow(color: type.color.opacity(0.3), radius: 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(DS.Fonts.labelBold)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text(type.label)
                                .font(DS.Fonts.tinyMono)
                                .foregroundColor(type.color.opacity(0.7))
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.15))
                            
                            Text(url.deletingLastPathComponent().lastPathComponent)
                                .font(DS.Fonts.tiny)
                                .foregroundColor(.white.opacity(0.3))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(type.color.opacity(0.15), lineWidth: 0.5)
                )
            }
            
            // Warning
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DS.Fonts.tiny)
                    .foregroundColor(.yellow.opacity(0.6))
                Text("Script will execute with your user permissions")
                    .font(DS.Fonts.tiny)
                    .foregroundColor(.white.opacity(0.35))
            }
            
            // Action buttons
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(DS.Anim.springFast) {
                        scriptDrop.cancelPending()
                    }
                }) {
                    Text("Cancel")
                        .font(DS.Fonts.bodySemi)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(DS.Anim.springFast) {
                        scriptDrop.confirmAndRun()
                    }
                    HapticManager.shared.play(.scriptLaunch)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(DS.Fonts.tiny)
                        Text("Execute")
                            .font(DS.Fonts.bodySemi)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .shadow(color: .green.opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Terminal Output View
    // ═══════════════════════════════════════
    
    private func scriptDropTerminalView() -> some View {
        VStack(spacing: 6) {
            // Status bar
            HStack(spacing: 8) {
                // Running indicator
                if scriptDrop.state == .running {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.6), radius: 4)
                        .modifier(PulseModifier())
                    
                    Text("Running...")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(.green.opacity(0.7))
                } else if scriptDrop.state == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Fonts.tiny)
                        .foregroundColor(.green)
                    Text("Success")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(.green.opacity(0.7))
                } else if case .failed(let code) = scriptDrop.state {
                    Image(systemName: "xmark.octagon.fill")
                        .font(DS.Fonts.tiny)
                        .foregroundColor(.red)
                    Text("Exit \(code)")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(.red.opacity(0.7))
                } else if scriptDrop.state == .killed {
                    Image(systemName: "stop.circle.fill")
                        .font(DS.Fonts.tiny)
                        .foregroundColor(.orange)
                    Text("Killed")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(.orange.opacity(0.7))
                }
                
                Spacer()
                
                // Lines count
                Text("\(scriptDrop.outputLines.count) lines")
                    .font(DS.Fonts.microMono)
                    .foregroundColor(.white.opacity(0.2))
                
                // Kill button (while running)
                if scriptDrop.state == .running {
                    Button(action: {
                        scriptDrop.killScript()
                        HapticManager.shared.play(.scriptKill)
                    }) {
                        Image(systemName: "stop.fill")
                            .font(DS.Fonts.tiny)
                            .foregroundColor(.red.opacity(0.7))
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(scriptDrop.outputLines) { line in
                            HStack(spacing: 4) {
                                Text(line.isError ? "E" : "›")
                                    .font(DS.Fonts.microMono)
                                    .foregroundColor(line.isError ? .red.opacity(0.5) : .green.opacity(0.3))
                                    .frame(width: 10, alignment: .center)
                                
                                Text(line.text)
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .foregroundColor(
                                        line.isError
                                            ? .red.opacity(0.75)
                                            : terminalLineColor(line.text)
                                    )
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .id(line.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(
                            scriptDrop.state == .running
                                ? Color.green.opacity(0.15)
                                : Color.white.opacity(0.04),
                            lineWidth: 0.5
                        )
                )
                .onChange(of: scriptDrop.outputLines.count) {
                    if let lastLine = scriptDrop.outputLines.last {
                        withAnimation(DS.Spring.snap) {
                            proxy.scrollTo(lastLine.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Re-run / New Drop after completion
            if scriptDrop.state == .success || scriptDrop.state != .idle && scriptDrop.state != .running && scriptDrop.state != .confirming {
                HStack(spacing: 8) {
                    if let url = scriptDrop.pendingScript {
                        Button(action: {
                            scriptDrop.handleDrop(url)
                            HapticManager.shared.play(.button)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(DS.Fonts.micro)
                                Text("Re-run")
                                    .font(DS.Fonts.tinySemi)
                            }
                            .foregroundColor(.cyan.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.cyan.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(DS.Anim.springFast) {
                            scriptDrop.cancelPending()
                        }
                    }) {
                        Text("Done")
                            .font(DS.Fonts.tinySemi)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - History Row
    // ═══════════════════════════════════════
    
    private func scriptHistoryRow(_ record: ScriptDropService.ScriptRecord) -> some View {
        let type = ScriptDropService.ScriptType(rawValue: record.type)
        
        return HStack(spacing: 8) {
            // Icon
            Image(systemName: type?.icon ?? "terminal")
                .font(DS.Fonts.tiny)
                .foregroundColor(type?.color ?? .gray)
                .frame(width: 18, height: 18)
                .background((type?.color ?? .gray).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(record.name)
                    .font(DS.Fonts.small)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(record.timeAgo)
                    .font(DS.Fonts.micro)
                    .foregroundColor(.white.opacity(0.2))
            }
            
            Spacer()
            
            // Status
            Image(systemName: record.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(DS.Fonts.micro)
                .foregroundColor(record.isSuccess ? .green.opacity(0.5) : .red.opacity(0.5))
            
            // Duration
            Text("\(record.durationMs)ms")
                .font(DS.Fonts.microMono)
                .foregroundColor(.white.opacity(0.2))
            
            // Favorite toggle
            Button(action: { scriptDrop.toggleFavorite(record) }) {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .font(DS.Fonts.micro)
                    .foregroundColor(record.isFavorite ? .yellow.opacity(0.6) : .white.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .onTapGesture {
            scriptDrop.rerun(record)
            HapticManager.shared.play(.button)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Terminal Helpers
    // ═══════════════════════════════════════
    
    /// Color-code terminal lines based on content for visual richness
    private func terminalLineColor(_ text: String) -> Color {
        if text.hasPrefix("▶") || text.hasPrefix("✅") { return .green.opacity(0.8) }
        if text.hasPrefix("─") { return .white.opacity(0.15) }
        if text.hasPrefix("  ") { return .white.opacity(0.4) } // Metadata lines
        return .white.opacity(0.6)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Pulse Animation Modifier
// ═══════════════════════════════════════════════════

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                DS.Spring.breath,
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
