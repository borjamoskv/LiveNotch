import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🧠 CortexPanelView — The Memory Interface
// ═══════════════════════════════════════════════════
// Expanded panel showing CORTEX memory state:
//   - Ghost list with resolve/dismiss actions
//   - Semantic search bar
//   - Quick store input
//   - Connection status + version

@available(macOS 14.0, *)
struct CortexPanelView: View {
    @ObservedObject var cortex: CortexController
    @ObservedObject var viewModel: NotchViewModel
    
    @State private var activeTab: Tab = .ghosts
    @State private var searchText: String = ""
    @State private var storeText: String = ""
    @State private var storeProject: String = "cortex"
    @State private var storeType: String = "ghost"
    
    enum Tab: String, CaseIterable {
        case ghosts = "Ghosts"
        case search = "Search"
        case store = "Store"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            PanelHeader(
                icon: "brain.fill",
                iconColor: cortexAccentColor,
                title: "CORTEX"
            ) {
                // Version + status badge
                connectionBadge
            } onClose: {
                closePanel()
            }
            
            // ── Tab Selector ──
            tabBar
            
            Divider()
                .background(DS.Colors.strokeSubtle)
                .padding(.horizontal, DS.Space.xl)
            
            // ── Content ──
            switch activeTab {
            case .ghosts:
                ghostsView
            case .search:
                searchView
            case .store:
                storeView
            }
        }
    }
    
    // ════════════════════════════════════
    // MARK: - Accent Color
    // ════════════════════════════════════
    
    private var cortexAccentColor: Color {
        switch cortex.connectionState {
        case .connected:
            switch cortex.ghostCount {
            case 0: return DS.Colors.yinmnBlue
            case 1...5: return Color(hue: 0.22, saturation: 1.0, brightness: 1.0)
            case 6...10: return Color(red: 212/255, green: 175/255, blue: 55/255) // Industrial Gold
            default: return .red.opacity(0.8)
            }
        case .disconnected: return DS.Colors.textGhost
        case .connecting: return DS.Colors.textMuted
        case .error: return .red.opacity(0.6)
        }
    }
    
    // ════════════════════════════════════
    // MARK: - Connection Badge
    // ════════════════════════════════════
    
    private var connectionBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(cortex.connectionState == .connected ? Color(hue: 0.22, saturation: 1.0, brightness: 1.0) : .red)
                .frame(width: 5, height: 5)
            
            Text("v\(cortex.version)")
                .font(DS.Fonts.microMono)
                .foregroundColor(DS.Colors.textMuted)
        }
    }
    
    // ════════════════════════════════════
    // MARK: - Tab Bar
    // ════════════════════════════════════
    
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(DS.Anim.springSnap) { activeTab = tab }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 8, weight: .semibold))
                        Text(tab.rawValue)
                            .font(DS.Fonts.microBold)
                        
                        if tab == .ghosts && cortex.ghostCount > 0 {
                            Text("\(cortex.ghostCount)")
                                .font(DS.Fonts.microMono)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(cortexAccentColor.opacity(0.6)))
                        }
                    }
                    .foregroundColor(activeTab == tab ? DS.Colors.textPrimary : DS.Colors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(activeTab == tab ? DS.Colors.surfaceLight : Color.clear)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, DS.Space.section)
        .padding(.vertical, DS.Space.sm)
    }
    
    private func tabIcon(_ tab: Tab) -> String {
        switch tab {
        case .ghosts: return "eye.fill"
        case .search: return "magnifyingglass"
        case .store: return "plus.circle.fill"
        }
    }
    
    // ════════════════════════════════════
    // MARK: - Ghosts View
    // ════════════════════════════════════
    
    private var ghostsView: some View {
        Group {
            if cortex.connectionState != .connected {
                offlineState
            } else if cortex.ghosts.isEmpty {
                emptyGhostState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(cortex.ghosts) { ghost in
                            ghostRow(ghost)
                        }
                    }
                    .padding(.horizontal, DS.Space.xl)
                    .padding(.vertical, DS.Space.md)
                }
                .frame(maxHeight: 180)
            }
        }
    }
    
    private func ghostRow(_ ghost: CortexFact) -> some View {
        HStack(spacing: 8) {
            // Project indicator
            Circle()
                .fill(projectColor(ghost.project))
                .frame(width: 6, height: 6)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(ghost.project)
                    .font(DS.Fonts.microBold)
                    .foregroundColor(DS.Colors.textTertiary)
                
                Text(ghost.content)
                    .font(DS.Fonts.small)
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Resolve button
            Button(action: {
                Task { await cortex.resolveGhost(ghost) }
                HapticManager.shared.play(.success)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Fonts.body)
                    .foregroundColor(Color(hue: 0.22, saturation: 1.0, brightness: 1.0).opacity(0.6))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(Color.purple.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(Color.purple.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private var emptyGhostState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hue: 0.22, saturation: 1.0, brightness: 1.0).opacity(0.5))
            
            Text("No ghosts — everything resolved")
                .font(DS.Fonts.small)
                .foregroundColor(DS.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var offlineState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 20))
                .foregroundColor(DS.Colors.textGhost)
            
            Text("CORTEX Offline")
                .font(DS.Fonts.small)
                .foregroundColor(DS.Colors.textMuted)
            
            Text("Start: uvicorn cortex.api:app")
                .font(DS.Fonts.microMono)
                .foregroundColor(DS.Colors.textGhost)
            
            Button("Retry Connection") {
                Task { await cortex.checkHealth() }
            }
            .font(DS.Fonts.tinyBold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // ════════════════════════════════════
    // MARK: - Search View
    // ════════════════════════════════════
    
    private var searchView: some View {
        VStack(spacing: 8) {
            // Search input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(DS.Fonts.small)
                    .foregroundColor(DS.Colors.textMuted)
                
                TextField("Search memory...", text: $searchText)
                    .font(DS.Fonts.body)
                    .foregroundColor(DS.Colors.textPrimary)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        guard !searchText.isEmpty else { return }
                        Task { await cortex.search(query: searchText) }
                    }
                
                if cortex.isSearching {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.surfaceLight)
            )
            .padding(.horizontal, DS.Space.xl)
            .padding(.top, DS.Space.md)
            
            // Results
            if !cortex.searchResults.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(cortex.searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                    .padding(.horizontal, DS.Space.xl)
                }
                .frame(maxHeight: 140)
            } else if !searchText.isEmpty && !cortex.isSearching {
                Text("No results")
                    .font(DS.Fonts.small)
                    .foregroundColor(DS.Colors.textGhost)
                    .padding(.vertical, 16)
            }
            
            Spacer().frame(height: DS.Space.md)
        }
    }
    
    private func searchResultRow(_ result: CortexSearchResult) -> some View {
        HStack(spacing: 6) {
            if let type = result.type {
                Image(systemName: typeIcon(type))
                    .font(.system(size: 8))
                    .foregroundColor(typeColor(type).opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                if let project = result.project {
                    Text(project)
                        .font(DS.Fonts.microBold)
                        .foregroundColor(DS.Colors.textTertiary)
                }
                Text(result.content)
                    .font(DS.Fonts.small)
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let score = result.score {
                Text(String(format: "%.0f%%", score * 100))
                    .font(DS.Fonts.microMono)
                    .foregroundColor(DS.Colors.textGhost)
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(DS.Colors.surfaceCard.opacity(0.5))
        )
    }
    
    // ════════════════════════════════════
    // MARK: - Store View
    // ════════════════════════════════════
    
    private var storeView: some View {
        VStack(spacing: 8) {
            // Project + Type selector
            HStack(spacing: 6) {
                // Project picker
                Menu {
                    ForEach(["cortex", "live-notch", "naroa-2026", "moskv-swarm", "general"], id: \.self) { proj in
                        Button(proj) { storeProject = proj }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(projectColor(storeProject))
                            .frame(width: 5, height: 5)
                        Text(storeProject)
                            .font(DS.Fonts.microBold)
                    }
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DS.Colors.surfaceLight))
                }
                
                // Type picker
                Menu {
                    ForEach(["ghost", "decision", "error", "knowledge", "task"], id: \.self) { type in
                        Button(action: { storeType = type }) {
                            Label(type, systemImage: typeIcon(type))
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: typeIcon(storeType))
                            .font(.system(size: 7))
                        Text(storeType)
                            .font(DS.Fonts.microBold)
                    }
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DS.Colors.surfaceLight))
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.top, DS.Space.md)
            
            // Content input
            HStack(spacing: 6) {
                TextField("What's on your mind...", text: $storeText)
                    .font(DS.Fonts.body)
                    .foregroundColor(DS.Colors.textPrimary)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        submitStore()
                    }
                
                if cortex.isStoring {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Button(action: { submitStore() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(DS.Fonts.title)
                            .foregroundColor(storeText.isEmpty ? DS.Colors.textGhost : Color(hue: 0.22, saturation: 1.0, brightness: 1.0))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(storeText.isEmpty)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.surfaceLight)
            )
            .padding(.horizontal, DS.Space.xl)
            
            // Status
            if let result = cortex.lastStoreResult {
                Text(result)
                    .font(DS.Fonts.microMono)
                    .foregroundColor(Color(hue: 0.22, saturation: 1.0, brightness: 1.0).opacity(0.7))
                    .transition(.opacity)
            }
            
            Spacer().frame(height: DS.Space.md)
        }
    }
    
    private func submitStore() {
        guard !storeText.isEmpty else { return }
        let content = storeText
        let project = storeProject
        let type = storeType
        Task {
            let success = await cortex.store(project: project, content: content, type: type)
            if success {
                storeText = ""
                HapticManager.shared.play(.success)
            }
        }
    }
    
    // ════════════════════════════════════
    // MARK: - Helpers
    // ════════════════════════════════════
    
    private func projectColor(_ project: String) -> Color {
        let hash = abs(project.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private func typeIcon(_ type: String) -> String {
        switch type {
        case "ghost": return "eye.fill"
        case "decision": return "checkmark.seal.fill"
        case "error": return "exclamationmark.triangle.fill"
        case "knowledge": return "book.fill"
        case "bridge": return "arrow.triangle.branch"
        case "rule": return "shield.fill"
        case "task": return "checklist"
        default: return "doc.fill"
        }
    }
    
    private func typeColor(_ type: String) -> Color {
        switch type {
        case "ghost": return .purple
        case "decision": return .green
        case "error": return .red
        case "knowledge": return DS.Colors.yinmnBlue
        case "bridge": return .cyan
        case "rule": return .orange
        case "task": return .yellow
        default: return .gray
        }
    }
    
    private func closePanel() {
        withAnimation(DS.Anim.springStd) {
            viewModel.isCortexVisible = false
        }
        HapticManager.shared.play(.toggle)
    }
}
