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
    ]
    .merging(ChameleonProfile.extendedProfiles) { current, _ in current }
