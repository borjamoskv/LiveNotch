import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🚀 Quick Launch Panel View
// ═══════════════════════════════════════════════════

struct QuickLaunchPanelView: View {
    @ObservedObject var launcher = QuickLaunchService.shared
    @ObservedObject var viewModel: NotchViewModel // Added dependency
    @State private var hoveredID: UUID?
    
    var body: some View {
        VStack(spacing: DS.Space.sm) {
            
            // ── Ecosystem Hub ──
            Button(action: {
                viewModel.isQuickLaunchVisible = false
                viewModel.isEcosystemHubVisible = true
                HapticManager.shared.play(.toggle)
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(DS.Fonts.smallBold)
                    Text("ECOSYSTEM HUB")
                        .font(DS.Fonts.tinyBold)
                        .tracking(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Fonts.microBold)
                        .opacity(0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            // ── Pinned Apps ──
            if !launcher.pinnedApps.isEmpty {
                sectionHeader(icon: "pin.fill", title: "PINNED", color: .yellow)
                appGrid(items: launcher.pinnedApps, pinnable: true)
            }
            
            // ── Running Apps ──
            if !launcher.recentApps.isEmpty {
                sectionHeader(icon: "circle.fill", title: "RUNNING", color: .green)
                appGrid(items: launcher.recentApps, pinnable: false)
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .onAppear { launcher.refreshRecentApps() }
    }
    
    // ── Section Header ──
    
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(DS.Fonts.micro)
                .foregroundColor(color.opacity(0.6))
            Text(title)
                .font(DS.Fonts.microBold)
                .foregroundColor(color.opacity(0.5))
                .tracking(1)
            Spacer()
        }
    }
    
    // ── App Grid ──
    
    private func appGrid(items: [QuickLaunchService.LaunchItem], pinnable: Bool) -> some View {
        let columns = [GridItem](repeating: GridItem(.flexible(), spacing: DS.Space.xs), count: 4)
        
        return LazyVGrid(columns: columns, spacing: DS.Space.sm) {
            ForEach(items) { item in
                appButton(item: item, pinnable: pinnable)
            }
        }
    }
    
    // ── App Button ──
    
    private func appButton(item: QuickLaunchService.LaunchItem, pinnable: Bool) -> some View {
        Button(action: {
            launcher.launch(item)
            HapticManager.shared.play(.toggle)
        }) {
            VStack(spacing: 3) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .shadow(color: .white.opacity(hoveredID == item.id ? 0.15 : 0), radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(DS.Fonts.h4)
                                .foregroundColor(.white.opacity(0.2))
                        )
                }
                
                Text(item.name)
                    .font(DS.Fonts.micro)
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(hoveredID == item.id ? 0.06 : 0.02))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredID = h ? item.id : nil }
        .contextMenu {
            if pinnable {
                // Already pinned — remove option
            } else if !launcher.isPinned(item.bundleID) {
                Button(action: { launcher.pin(item) }) {
                    Label("Pin to Quick Launch", systemImage: "pin.fill")
                }
            }
            if launcher.isPinned(item.bundleID) {
                Button(role: .destructive, action: { launcher.unpin(item) }) {
                    Label("Unpin", systemImage: "pin.slash")
                }
            }
        }
    }
}
