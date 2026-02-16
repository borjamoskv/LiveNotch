import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎨 App Profiles — Icon, Color, Action
// ═══════════════════════════════════════════════════

/// Smart Actions for the Notch
enum SmartAction {
    case nextTrack
    case expandPanel
    case toggleTimer
    case showMeeting
    case appAction      // 🦎 Context-aware app action
}

struct ChameleonProfile {
    let accentColor: Color
    let icon: String
    let actionLabel: String
    let action: SmartAction
    let breathMod: Double  // Breathing rate multiplier (0.5 = slow, 2.0 = fast)
}

// Global lookup for app profiles
let chameleonProfiles: [String: ChameleonProfile] = [
    // ── Development ──
    "com.microsoft.VSCode": ChameleonProfile(
        accentColor: Color(red: 0.0, green: 0.48, blue: 0.8),  // #007ACC
        icon: "play.fill",
        actionLabel: "Build",
        action: .appAction,
        breathMod: 0.8
    ),
    "com.apple.dt.Xcode": ChameleonProfile(
        accentColor: Color(red: 0.0, green: 0.6, blue: 0.9),
        icon: "hammer.fill",
        actionLabel: "Build",
        action: .appAction,
        breathMod: 1.0
    ),
    "com.googlecode.iterm2": ChameleonProfile(
        accentColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        icon: "terminal.fill",
        actionLabel: "Terminal",
        action: .expandPanel,
        breathMod: 0.7
    ),
    "com.apple.Terminal": ChameleonProfile(
        accentColor: Color(red: 0.16, green: 0.79, blue: 0.25),
        icon: "terminal.fill",
        actionLabel: "Terminal",
        action: .expandPanel,
        breathMod: 0.7
    ),
    
    // ── Browsers ──
    "com.apple.Safari": ChameleonProfile(
        accentColor: Color(red: 0.06, green: 0.71, blue: 0.93),  // Safari blue
        icon: "arrow.clockwise",
        actionLabel: "Reload",
        action: .appAction,
        breathMod: 1.0
    ),
    "com.google.Chrome": ChameleonProfile(
        accentColor: Color(red: 0.26, green: 0.52, blue: 0.96),  // Chrome blue
        icon: "arrow.clockwise",
        actionLabel: "Reload",
        action: .appAction,
        breathMod: 1.0
    ),
    "company.thebrowser.Browser": ChameleonProfile(  // Arc
        accentColor: Color(red: 0.55, green: 0.35, blue: 1.0),  // Arc purple
        icon: "arrow.clockwise",
        actionLabel: "Reload",
        action: .appAction,
        breathMod: 1.0
    ),
    "com.brave.Browser": ChameleonProfile(
        accentColor: Color(red: 1.0, green: 0.3, blue: 0.15),  // Brave orange
        icon: "shield.fill",
        actionLabel: "Shields",
        action: .appAction,
        breathMod: 1.0
    ),
    
    // ── Creative ──
    "com.adobe.Photoshop": ChameleonProfile(
        accentColor: Color(red: 0.1, green: 0.1, blue: 0.25),  // PS dark blue
        icon: "paintbrush.fill",
        actionLabel: "Brush",
        action: .appAction,
        breathMod: 1.5
    ),
    "com.adobe.Illustrator": ChameleonProfile(
        accentColor: Color(red: 1.0, green: 0.6, blue: 0.0),   // AI orange
        icon: "pencil.tip.crop.circle",
        actionLabel: "Pen",
        action: .appAction,
        breathMod: 1.5
    ),
    "com.figma.Desktop": ChameleonProfile(
        accentColor: Color(red: 0.9, green: 0.3, blue: 0.2),   // Sigma red-orange
        icon: "square.dashed",
        actionLabel: "Frame",
        action: .appAction,
        breathMod: 1.2
    ),
    "com.seriflabs.affinitydesigner2": ChameleonProfile(
        accentColor: Color(red: 0.2, green: 0.4, blue: 0.8),
        icon: "pencil.and.outline",
        actionLabel: "Draw",
        action: .appAction,
        breathMod: 1.5
    ),
    "com.procreate.canvases": ChameleonProfile(  // Procreate (if on Mac/Catalyst)
        accentColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        icon: "paintpalette.fill",
        actionLabel: "Create",
        action: .appAction,
        breathMod: 1.5
    ),
    
    // IA #9: Cursor (El Constructor)
    "com.todesktop.230510fqmkbjh6g": ChameleonProfile( // Cursor Legacy Bundle ID
        accentColor: Color(red: 0.1, green: 0.1, blue: 0.1), // Cursor Dark
        icon: "hammer.fill",
        actionLabel: "Refactor",
        action: .appAction,
        breathMod: 0.8
    ),

    // ── Communication ──
    "com.tinyspeck.slackmacgap": ChameleonProfile(
        accentColor: Color(red: 0.29, green: 0.08, blue: 0.30),  // Slack aubergine
        icon: "bell.slash.fill",
        actionLabel: "Mute",
        action: .appAction,
        breathMod: 1.2
    ),
    "ru.keepcoder.Telegram": ChameleonProfile(
        accentColor: Color(red: 0.16, green: 0.63, blue: 0.88),  // Telegram blue
        icon: "paperplane.fill",
        actionLabel: "Send",
        action: .expandPanel,
        breathMod: 1.0
    ),
    "com.apple.MobileSMS": ChameleonProfile(
        accentColor: Color(red: 0.2, green: 0.78, blue: 0.35),  // iMessage green
        icon: "bubble.left.fill",
        actionLabel: "Message",
        action: .expandPanel,
        breathMod: 1.0
    ),
    
    // ── Meetings ──
    "us.zoom.xos": ChameleonProfile(
        accentColor: Color(red: 0.18, green: 0.55, blue: 1.0),  // Zoom blue
        icon: "mic.slash.fill",
        actionLabel: "Mute",
        action: .showMeeting,
        breathMod: 0
    ),
    "com.apple.FaceTime": ChameleonProfile(
        accentColor: Color(red: 0.2, green: 0.78, blue: 0.35),
        icon: "video.fill",
        actionLabel: "FaceTime",
        action: .showMeeting,
        breathMod: 0
    ),
    "com.microsoft.teams": ChameleonProfile(
        accentColor: Color(red: 0.29, green: 0.34, blue: 0.56),  // Teams indigo
        icon: "mic.slash.fill",
        actionLabel: "Mute",
        action: .showMeeting,
        breathMod: 0
    ),
    "com.microsoft.teams2": ChameleonProfile(
        accentColor: Color(red: 0.29, green: 0.34, blue: 0.56),
        icon: "mic.slash.fill",
        actionLabel: "Mute",
        action: .showMeeting,
        breathMod: 0
    ),
    
    // ── Music (handled by music mood, but color/icon defined for transitions) ──
    "com.spotify.client": ChameleonProfile(
        accentColor: Color(red: 0.12, green: 0.84, blue: 0.38),  // Spotify green
        icon: "forward.fill",
        actionLabel: "Next",
        action: .nextTrack,
        breathMod: 1.0
    ),
    "com.apple.Music": ChameleonProfile(
        accentColor: Color(red: 0.98, green: 0.24, blue: 0.36),  // Apple Music pink
        icon: "forward.fill",
        actionLabel: "Next",
        action: .nextTrack,
        breathMod: 1.0
    ),
    
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
    ),
]
