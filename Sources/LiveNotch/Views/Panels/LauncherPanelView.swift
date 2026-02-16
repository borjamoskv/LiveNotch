import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🚀 Launcher Panel (App Grid)
// ═══════════════════════════════════════════════════
// "The Missing Button" — Instant access to favorite apps.
// Style: ALCOVE Industrial Noir (Deep, Glass, Neon Accents)

struct LauncherPanelView: View {
    
    // ── Grid Configuration ──
    let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]
    
    // ── Pre-defined Apps (MVP) ──
    // TODO: Make this dynamic/user-configurable in Phase 2
    let apps: [LaunchApp] = [
        LaunchApp(name: "Finder", bundleId: "com.apple.finder", systemImage: "magnifyingglass"),
        LaunchApp(name: "Safari", bundleId: "com.apple.Safari", systemImage: "safari"),
        LaunchApp(name: "Terminal", bundleId: "com.apple.Terminal", systemImage: "terminal.fill"),
        LaunchApp(name: "Mail", bundleId: "com.apple.mail", systemImage: "envelope.fill"),
        LaunchApp(name: "Music", bundleId: "com.apple.Music", systemImage: "music.note"),
        LaunchApp(name: "Notes", bundleId: "com.apple.Notes", systemImage: "note.text"),
        LaunchApp(name: "Messages", bundleId: "com.apple.MobileSMS", systemImage: "message.fill"),
        LaunchApp(name: "Calendar", bundleId: "com.apple.iCal", systemImage: "calendar"),
        LaunchApp(name: "Photos", bundleId: "com.apple.Photos", systemImage: "photo.fill"),
        LaunchApp(name: "Settings", bundleId: "com.apple.systempreferences", systemImage: "gear"),
        LaunchApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", systemImage: "bubble.left.and.bubble.right.fill"), // Common dev app
        LaunchApp(name: "VS Code", bundleId: "com.microsoft.VSCode", systemImage: "chevron.left.forwardslash.chevron.right") // Common dev app
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // ── Header ──
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(DS.Fonts.title)
                        .foregroundColor(DS.Colors.champagneGold)
                        .shadow(color: DS.Colors.champagneGold.opacity(0.4), radius: 4)
                        
                    Text("LAUNCHER")
                        .font(DS.Fonts.labelBold)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tracking(1.0)
                }
                
                Spacer()
                
                // Close Button (Standardized)
                Button(action: {
                    NotificationCenter.default.post(name: .closePanel, object: nil)
                    HapticManager.shared.play(.toggle)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DS.Fonts.title)
                        .foregroundColor(DS.Colors.textMuted)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DS.Space.section)
            
            // ── App Grid ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(apps) { app in
                        AppIconView(app: app)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: 200) // Contain height within panel limits
        }
        .padding(.vertical, 10)
    }
}

// ── App Icon View ──
struct AppIconView: View {
    let app: LaunchApp
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            launchApp(bundleId: app.bundleId)
            HapticManager.shared.play(.heavy) // Satisfying click
        }) {
            VStack(spacing: 8) {
                // Icon Container
                ZStack {
                    // Glass Background
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isHovered ? DS.Colors.glassLayer1 : DS.Colors.glassLayer2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isHovered ? DS.Colors.champagneGold.opacity(0.3) : DS.Colors.glassBorder.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: isHovered ? DS.Colors.champagneGold.opacity(0.15) : .clear, radius: 8)
                    
                    // Icon
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) {
                         Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    } else {
                        // Fallback Icon
                        Image(systemName: app.systemImage)
                            .font(.system(size: 24))
                            .foregroundColor(isHovered ? DS.Colors.champagneGold : .white.opacity(0.7))
                    }
                }
                .frame(width: 52, height: 52)
                
                // Name
                Text(app.name)
                    .font(DS.Fonts.micro)
                    .foregroundColor(isHovered ? .white : .white.opacity(0.5))
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(DS.Anim.liquidSpring, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
            if hover { HapticManager.shared.play(.alignment) }
        }
    }
    
    // Updated launch method: Try bundle ID first, fallback to name search if needed (though bundle ID is robust)
    private func launchApp(bundleId: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                 DispatchQueue.main.async {
                     NotificationCenter.default.post(name: .closePanel, object: nil)
                }
            }
        } else {
            NSLog("⚠️ LauncherPanel: Could not find app with bundleId: %@", bundleId)
        }
    }
}

// ── Data Model ──
struct LaunchApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let systemImage: String
}

// ── Helper Notification for closing ──
extension Notification.Name {
    static let closePanel = Notification.Name("closePanel")
}
