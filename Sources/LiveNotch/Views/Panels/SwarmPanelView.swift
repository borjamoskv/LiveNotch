import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🐝 SwarmPanelView — The Expanded Hive View
// ═══════════════════════════════════════════════════
// When the notch expands and swarm is active, this shows:
//   - Agent list with health bars and status
//   - Visual task descriptions
//   - Kill/spawn controls
//   - Activity log

@available(macOS 14.0, *)
struct SwarmPanelView: View {
    @ObservedObject var swarm: SwarmEngine
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerRow
            
            Divider()
                .background(DS.Colors.strokeSubtle)
                .padding(.horizontal, DS.Space.xl)
            
            // ── Agent Grid ──
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(swarm.livingAgents) { agent in
                        agentRow(agent)
                    }
                    
                    if swarm.livingAgents.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.vertical, DS.Space.md)
            }
            .frame(maxHeight: 160)
            
            Divider()
                .background(DS.Colors.strokeSubtle)
                .padding(.horizontal, DS.Space.xl)
            
            // ── Bottom Bar: Log + Spawn ──
            bottomBar
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Header
    // ═══════════════════════════════════════
    
    private var headerRow: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "ant.fill")
                    .font(DS.Fonts.title)
                    .foregroundColor(DS.Colors.textPrimary)
                    .symbolEffect(.pulse.wholeSymbol, isActive: swarm.isActive)
                
                Text("SWARM")
                    .font(DS.Fonts.labelBold)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("(\(swarm.livingAgents.count) agents)")
                    .font(DS.Fonts.tinyMono)
                    .foregroundColor(DS.Colors.textMuted)
            }
            
            Spacer()
            
            // Spawn Quick Button
            Button(action: { spawnRandom() }) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Fonts.title)
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Close
            Button(action: { closePanel() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Fonts.title)
                    .foregroundColor(DS.Colors.textMuted)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.Space.section)
        .padding(.vertical, DS.Space.md)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Agent Row
    // ═══════════════════════════════════════
    
    private func agentRow(_ agent: SwarmAgent) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: agent.role.icon)
                .font(DS.Fonts.small)
                .foregroundColor(agent.role.color)
                .frame(width: 16, height: 16)
            
            // Name + Task
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.role.rawValue)
                    .font(DS.Fonts.tinyBold)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if agent.isWorking {
                    Text(agent.currentTask)
                        .font(DS.Fonts.microMono)
                        .foregroundColor(DS.Colors.textMuted)
                        .lineLimit(1)
                } else {
                    Text("idle")
                        .font(DS.Fonts.microMono)
                        .foregroundColor(DS.Colors.textGhost)
                }
            }
            
            Spacer()
            
            // Health Bar
            healthBar(health: agent.health, color: agent.role.color)
            
            // Progress (if working)
            if agent.isWorking {
                progressRing(progress: agent.progress, color: agent.role.color)
            }
            
            // Kill button
            Button(action: { swarm.kill(agent) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(DS.Colors.textGhost)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(agent.isWorking ? agent.role.color.opacity(0.04) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(agent.isWorking ? agent.role.color.opacity(0.08) : Color.clear, lineWidth: 0.5)
        )
    }
    
    // ═══════════════════════════════════════
    // MARK: - Components
    // ═══════════════════════════════════════
    
    private func healthBar(health: Double, color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(DS.Colors.surfaceLight)
                .frame(width: 30, height: 3)
            
            Capsule()
                .fill(health > 0.3 ? color : .red)
                .frame(width: CGFloat(max(0, health)) * 30, height: 3)
        }
    }
    
    private func progressRing(progress: Double, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.surfaceLight, lineWidth: 1.5)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12, height: 12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "ant.fill")
                .font(.system(size: 20))
                .foregroundColor(DS.Colors.textGhost)
            
            Text("No agents active")
                .font(DS.Fonts.small)
                .foregroundColor(DS.Colors.textMuted)
            
            Button("Spawn Demo Swarm") {
                swarm.spawnDemoSwarm()
            }
            .font(DS.Fonts.tinyBold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 20)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Bottom Bar
    // ═══════════════════════════════════════
    
    private var bottomBar: some View {
        HStack(spacing: 8) {
            // Last log entry
            if let last = swarm.swarmLog.last {
                HStack(spacing: 4) {
                    Circle()
                        .fill(last.agentRole.color)
                        .frame(width: 4, height: 4)
                    
                    Text(last.message)
                        .font(DS.Fonts.microMono)
                        .foregroundColor(DS.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Spawn role picker
            Menu {
                ForEach(AgentRole.allCases) { role in
                    Button(action: { swarm.spawn(role) }) {
                        Label(role.rawValue, systemImage: role.icon)
                    }
                }
                
                Divider()
                
                Button("Spawn Demo Swarm") {
                    swarm.spawnDemoSwarm()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 7, weight: .bold))
                    Text("SPAWN")
                        .font(DS.Fonts.microBold)
                }
                .foregroundColor(DS.Colors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(DS.Colors.surfaceLight))
            }
        }
        .padding(.horizontal, DS.Space.section)
        .padding(.vertical, DS.Space.sm)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Actions
    // ═══════════════════════════════════════
    
    private func spawnRandom() {
        let role = AgentRole.allCases.randomElement() ?? .researcher
        swarm.spawn(role)
        HapticManager.shared.play(.toggle)
    }
    
    private func closePanel() {
        withAnimation(DS.Anim.springStd) {
            viewModel.isSwarmVisible = false
        }
        HapticManager.shared.play(.toggle)
    }
}
