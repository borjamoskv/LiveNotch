import SwiftUI

extension ChameleonProfile {
    static let extendedProfiles: [String: ChameleonProfile] = [
        // ── Productivity ──
        "com.apple.finder": ChameleonProfile(
            accentColor: Color(red: 0.26, green: 0.52, blue: 0.96),
            icon: "folder.fill",
            actionLabel: "New Folder",
            action: .expandPanel,
            breathMod: 1.5
        ),
        "com.apple.Notes": ChameleonProfile(
            accentColor: Color(red: 0.97, green: 0.82, blue: 0.28),  // Notes yellow
            icon: "square.and.pencil",
            actionLabel: "New Note",
            action: .expandPanel,
            breathMod: 1.2
        ),
        "com.apple.mail": ChameleonProfile(
            accentColor: Color(red: 0.2, green: 0.52, blue: 1.0),
            icon: "envelope.fill",
            actionLabel: "Compose",
            action: .expandPanel,
            breathMod: 1.0
        ),
        "notion.id": ChameleonProfile(
            accentColor: Color.white.opacity(0.7),
            icon: "doc.text.fill",
            actionLabel: "Notion",
            action: .expandPanel,
            breathMod: 1.0
        ),
        "md.obsidian": ChameleonProfile(
            accentColor: Color(red: 0.48, green: 0.31, blue: 0.85),  // Obsidian purple
            icon: "doc.text.fill",
            actionLabel: "Vault",
            action: .expandPanel,
            breathMod: 1.0
        ),
        
        // ── System ──
        "com.apple.systempreferences": ChameleonProfile(
            accentColor: Color.gray.opacity(0.5),
            icon: "gear",
            actionLabel: "Settings",
            action: .expandPanel,
            breathMod: 2.0
        ),
        "com.apple.ActivityMonitor": ChameleonProfile(
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.4),
            icon: "chart.bar.fill",
            actionLabel: "Activity",
            action: .expandPanel,
            breathMod: 0.6
        ),
        
        // ── AI / LLM ──
        "com.google.antigravity": ChameleonProfile(
            accentColor: Color(red: 0.4, green: 0.3, blue: 0.9),  // Antigravity purple
            icon: "wand.and.stars",
            actionLabel: "Code",
            action: .appAction,
            breathMod: 0.8
        ),
        
        // ── Utilities ──
        "com.knollsoft.Rectangle": ChameleonProfile(
            accentColor: Color(red: 0.3, green: 0.7, blue: 0.4),  // Rectangle green
            icon: "rectangle.split.2x2",
            actionLabel: "Layout",
            action: .expandPanel,
            breathMod: 2.0
        ),
        "me.damir.dropover-mac": ChameleonProfile(
            accentColor: Color(red: 0.5, green: 0.7, blue: 1.0),  // Dropover blue
            icon: "tray.and.arrow.down.fill",
            actionLabel: "Shelf",
            action: .expandPanel,
            breathMod: 1.5
        ),
        
        // ── Editors ──
        "com.todesktop.230313mzl4w4u92": ChameleonProfile(  // Cursor
            accentColor: Color(red: 0.0, green: 0.48, blue: 0.8),  // Cursor blue (like VS Code)
            icon: "play.fill",
            actionLabel: "Run",
            action: .appAction,
            breathMod: 0.8
        ),
        
        // ── Own Apps ──
        "com.moskv.systemforge-pro": ChameleonProfile(  // SystemForge Pro
            accentColor: Color(red: 0.85, green: 0.4, blue: 0.1),  // Forge orange
            icon: "hammer.fill",
            actionLabel: "Forge",
            action: .appAction,
            breathMod: 0.7
        ),
        "com.moskv.listlyzer": ChameleonProfile(  // Listlyzer
            accentColor: Color(red: 0.3, green: 0.75, blue: 0.95),  // Listlyzer cyan
            icon: "list.bullet.rectangle.fill",
            actionLabel: "Analyze",
            action: .appAction,
            breathMod: 0.9
        ),
        "com.moskv.soulcheck": ChameleonProfile(  // SoulCheck — daily button
            accentColor: Color(red: 0.85, green: 0.25, blue: 0.6),  // Soul magenta
            icon: "heart.fill",
            actionLabel: "Check",
            action: .appAction,
            breathMod: 1.0
        ),
        
        // ── Music Production ──
        "com.image-line.flstudio": ChameleonProfile(  // FL Studio
            accentColor: Color(red: 0.95, green: 0.55, blue: 0.1),  // FL orange
            icon: "waveform",
            actionLabel: "Studio",
            action: .appAction,
            breathMod: 0.6
        ),
        "com.example.SoulseekQt": ChameleonProfile(  // Soulseek
            accentColor: Color(red: 0.6, green: 0.75, blue: 0.3),  // Soulseek olive
            icon: "arrow.down.circle.fill",
            actionLabel: "Seek",
            action: .expandPanel,
            breathMod: 1.2
        ),
        
        // ── Media ──
        "com.apple.Preview": ChameleonProfile(
            accentColor: Color(red: 0.3, green: 0.6, blue: 0.9),
            icon: "doc.richtext",
            actionLabel: "Preview",
            action: .expandPanel,
            breathMod: 1.5
        ),
        "com.apple.Photos": ChameleonProfile(
            accentColor: Color(red: 1.0, green: 0.45, blue: 0.5),  // Photos gradient pink
            icon: "photo.fill",
            actionLabel: "Photos",
            action: .expandPanel,
            breathMod: 1.2
        ),
        
        // ── Calendar & Reminders ──
        "com.apple.iCal": ChameleonProfile(
            accentColor: Color(red: 0.95, green: 0.3, blue: 0.3),  // Calendar red
            icon: "calendar",
            actionLabel: "Calendar",
            action: .expandPanel,
            breathMod: 1.5
        ),
        "com.apple.reminders": ChameleonProfile(
            accentColor: Color(red: 0.0, green: 0.6, blue: 1.0),
            icon: "checklist",
            actionLabel: "Tasks",
            action: .expandPanel,
            breathMod: 1.5
        ),
        
        // ── Comms extras ──
        "net.whatsapp.WhatsApp": ChameleonProfile(
            accentColor: Color(red: 0.15, green: 0.84, blue: 0.42),  // WhatsApp green
            icon: "bubble.left.fill",
            actionLabel: "Chat",
            action: .expandPanel,
            breathMod: 1.0
        ),
        
        // ── Terminal extras ──
        "dev.warp.Warp-Stable": ChameleonProfile(
            accentColor: Color(red: 0.0, green: 0.9, blue: 0.7),  // Warp teal
            icon: "terminal.fill",
            actionLabel: "Terminal",
            action: .expandPanel,
            breathMod: 0.7
        )
    ]
}
