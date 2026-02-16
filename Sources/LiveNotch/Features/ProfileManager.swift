import Cocoa
import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎯 Profile Manager — Per-App Profiles
// ═══════════════════════════════════════════════════
// Detecta app activa via NSWorkspace, cambia wings + acciones automáticamente.
// Regla: cada app tiene su cockpit.

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published private(set) var activeApp: NSRunningApplication?
    @Published private(set) var activeBundleID: String = ""
    @Published private(set) var activeAppName: String = ""
    @Published private(set) var currentProfile: AppProfile = .default
    
    // All registered profile rules
    private let rules: [ProfileRule] = ProfileRule.builtIn
    
    private init() {}
    
    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            DispatchQueue.main.async {
                self?.apply(app)
            }
        }
        
        // Initial state
        if let app = NSWorkspace.shared.frontmostApplication {
            apply(app)
        }
    }
    
    private func apply(_ app: NSRunningApplication) {
        activeApp = app
        activeBundleID = app.bundleIdentifier ?? ""
        activeAppName = app.localizedName ?? ""
        
        if let matched = resolveProfile(bundleID: activeBundleID, appName: activeAppName) {
            currentProfile = matched
        } else {
            currentProfile = .default
        }
    }
    
    private func resolveProfile(bundleID: String, appName: String) -> AppProfile? {
        for rule in rules {
            if rule.matches(bundleID: bundleID, appName: appName) {
                return rule.profile
            }
        }
        return nil
    }
    
    /// Update accent color of the current profile
    func updateAccentColor(_ color: String) {
        currentProfile.accentColor = color
    }
}

// ═══════════════════════════════════════════════════
// MARK: - App Profile
// ═══════════════════════════════════════════════════

struct AppProfile: Hashable {
    let name: String
    let leadingLabel: String
    let trailingLabel: String
    let paletteActions: [CommandAction]
    var accentColor: String  // "blue", "green", "orange", "yinmn", etc.
    let icon: String         // SF Symbol
    
    static let `default` = AppProfile(
        name: "Default",
        leadingLabel: "NOTCH//WINGS",
        trailingLabel: "READY",
        paletteActions: CommandAction.defaults,
        accentColor: "white",
        icon: "sparkles"
    )
}

// ═══════════════════════════════════════════════════
// MARK: - Profile Matching Rules
// ═══════════════════════════════════════════════════

struct ProfileRule {
    enum Match {
        case bundleID(String)
        case bundlePrefix(String)
        case appName(String)
        case appNameContains(String)
    }
    
    let match: Match
    let profile: AppProfile
    
    func matches(bundleID: String, appName: String) -> Bool {
        switch match {
        case .bundleID(let s): return bundleID == s
        case .bundlePrefix(let s): return bundleID.hasPrefix(s)
        case .appName(let s): return appName == s
        case .appNameContains(let s): return appName.lowercased().contains(s.lowercased())
        }
    }
    
    // ── Built-in profiles ──
    static let builtIn: [ProfileRule] = [
        // Terminal
        .init(match: .bundleID("com.apple.Terminal"), profile: AppProfile(
            name: "Terminal",
            leadingLabel: "Terminal",
            trailingLabel: "SHELL",
            paletteActions: [
                .init(title: "New Tab", subtitle: "⌘T", kind: .keystroke(key: "t", modifiers: [.command])),
                .init(title: "Clear Screen", subtitle: "⌘K", kind: .keystroke(key: "k", modifiers: [.command])),
                .init(title: "Kill Process", subtitle: "⌃C", kind: .keystroke(key: "c", modifiers: [.control])),
            ] + CommandAction.defaults,
            accentColor: "green",
            icon: "terminal"
        )),
        
        // VS Code / Cursor
        .init(match: .bundlePrefix("com.microsoft.VSCode"), profile: AppProfile(
            name: "VS Code",
            leadingLabel: "VS Code",
            trailingLabel: "CODE",
            paletteActions: [
                .init(title: "Command Palette", subtitle: "⌘⇧P", kind: .keystroke(key: "p", modifiers: [.command, .shift])),
                .init(title: "Toggle Terminal", subtitle: "⌃`", kind: .keystroke(key: "`", modifiers: [.control])),
                .init(title: "Quick Open", subtitle: "⌘P", kind: .keystroke(key: "p", modifiers: [.command])),
            ] + CommandAction.defaults,
            accentColor: "blue",
            icon: "chevron.left.forwardslash.chevron.right"
        )),
        
        // Cursor IDE
        .init(match: .bundlePrefix("com.todesktop."), profile: AppProfile(
            name: "Cursor",
            leadingLabel: "Cursor",
            trailingLabel: "AI",
            paletteActions: [
                .init(title: "AI Chat", subtitle: "⌘L", kind: .keystroke(key: "l", modifiers: [.command])),
                .init(title: "Generate", subtitle: "⌘K", kind: .keystroke(key: "k", modifiers: [.command])),
                .init(title: "Toggle Terminal", subtitle: "⌃`", kind: .keystroke(key: "`", modifiers: [.control])),
            ] + CommandAction.defaults,
            accentColor: "purple",
            icon: "wand.and.stars"
        )),
        
        // Safari
        .init(match: .bundleID("com.apple.Safari"), profile: AppProfile(
            name: "Safari",
            leadingLabel: "Safari",
            trailingLabel: "WEB",
            paletteActions: [
                .init(title: "New Tab", subtitle: "⌘T", kind: .keystroke(key: "t", modifiers: [.command])),
                .init(title: "Reload", subtitle: "⌘R", kind: .keystroke(key: "r", modifiers: [.command])),
                .init(title: "Private Window", subtitle: "⌘⇧N", kind: .keystroke(key: "n", modifiers: [.command, .shift])),
            ] + CommandAction.defaults,
            accentColor: "blue",
            icon: "safari"
        )),
        
        // Chrome
        .init(match: .bundleID("com.google.Chrome"), profile: AppProfile(
            name: "Chrome",
            leadingLabel: "Chrome",
            trailingLabel: "WEB",
            paletteActions: [
                .init(title: "New Tab", subtitle: "⌘T", kind: .keystroke(key: "t", modifiers: [.command])),
                .init(title: "DevTools", subtitle: "⌥⌘I", kind: .keystroke(key: "i", modifiers: [.command, .option])),
                .init(title: "Reload", subtitle: "⌘R", kind: .keystroke(key: "r", modifiers: [.command])),
            ] + CommandAction.defaults,
            accentColor: "blue",
            icon: "globe"
        )),
        
        // Figma
        .init(match: .bundlePrefix("com.figma."), profile: AppProfile(
            name: "Figma",
            leadingLabel: "Figma",
            trailingLabel: "DESIGN",
            paletteActions: [
                .init(title: "Quick Search", subtitle: "/", kind: .keystroke(key: "/", modifiers: [])),
                .init(title: "Zoom to Fit", subtitle: "⌘1", kind: .keystroke(key: "1", modifiers: [.command])),
                .init(title: "Hand Tool", subtitle: "H", kind: .keystroke(key: "h", modifiers: [])),
            ] + CommandAction.defaults,
            accentColor: "purple",
            icon: "pencil.and.outline"
        )),
        
        // Ableton Live
        .init(match: .appNameContains("ableton"), profile: AppProfile(
            name: "Ableton",
            leadingLabel: "Ableton",
            trailingLabel: "LIVE",
            paletteActions: [
                .init(title: "Play/Stop", subtitle: "Space", kind: .keystroke(key: " ", modifiers: [])),
                .init(title: "Record", subtitle: "F9", kind: .shell(command: "")),
                .init(title: "Save", subtitle: "⌘S", kind: .keystroke(key: "s", modifiers: [.command])),
            ] + CommandAction.defaults,
            accentColor: "orange",
            icon: "waveform"
        )),
        
        // Logic Pro
        .init(match: .bundleID("com.apple.logic10"), profile: AppProfile(
            name: "Logic Pro",
            leadingLabel: "Logic",
            trailingLabel: "STUDIO",
            paletteActions: [
                .init(title: "Play/Stop", subtitle: "Space", kind: .keystroke(key: " ", modifiers: [])),
                .init(title: "Record", subtitle: "R", kind: .keystroke(key: "r", modifiers: [])),
                .init(title: "Mixer", subtitle: "X", kind: .keystroke(key: "x", modifiers: [])),
            ] + CommandAction.defaults,
            accentColor: "indigo",
            icon: "pianokeys"
        )),
        
        // Spotify
        .init(match: .bundleID("com.spotify.client"), profile: AppProfile(
            name: "Spotify",
            leadingLabel: "Spotify",
            trailingLabel: "MUSIC",
            paletteActions: CommandAction.defaults,
            accentColor: "green",
            icon: "music.note"
        )),
        
        // Finder
        .init(match: .bundleID("com.apple.finder"), profile: AppProfile(
            name: "Finder",
            leadingLabel: "Finder",
            trailingLabel: "FILES",
            paletteActions: [
                .init(title: "New Folder", subtitle: "⌘⇧N", kind: .keystroke(key: "n", modifiers: [.command, .shift])),
                .init(title: "Go to Folder", subtitle: "⌘⇧G", kind: .keystroke(key: "g", modifiers: [.command, .shift])),
                .init(title: "Get Info", subtitle: "⌘I", kind: .keystroke(key: "i", modifiers: [.command])),
            ] + CommandAction.defaults,
            accentColor: "blue",
            icon: "folder"
        )),
    ]
}

// ═══════════════════════════════════════════════════
// MARK: - Command Action (Palette Items)
// ═══════════════════════════════════════════════════

struct CommandAction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let kind: Kind
    
    enum Kind: Hashable {
        case keystroke(key: String, modifiers: [ModifierKey])
        case shell(command: String)
        case url(String)
        case shortcut(name: String) // Shortcuts.app
    }
    
    enum ModifierKey: Hashable {
        case command, shift, option, control
    }
    
    // Execute this action
    func execute() {
        switch kind {
        case .keystroke(let key, let modifiers):
            sendKeystroke(key: key, modifiers: modifiers)
        case .shell(let command):
            guard !command.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "do shell script \"\(command)\""
                let appleScript = NSAppleScript(source: script)
                var err: NSDictionary?
                appleScript?.executeAndReturnError(&err)
            }
        case .url(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .shortcut(let name):
            let script = "tell application \"Shortcuts\" to run shortcut \"\(name)\""
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var err: NSDictionary?
                appleScript?.executeAndReturnError(&err)
            }
        }
    }
    
    private func sendKeystroke(key: String, modifiers: [ModifierKey]) {
        var modStr = ""
        var mods: [String] = []
        if modifiers.contains(.command) { mods.append("command down") }
        if modifiers.contains(.shift) { mods.append("shift down") }
        if modifiers.contains(.option) { mods.append("option down") }
        if modifiers.contains(.control) { mods.append("control down") }
        
        if mods.isEmpty {
            modStr = ""
        } else {
            modStr = " using {\(mods.joined(separator: ", "))}"
        }
        
        let script = "tell application \"System Events\" to keystroke \"\(key)\"\(modStr)"
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var err: NSDictionary?
            appleScript?.executeAndReturnError(&err)
        }
    }
    
    // Default actions available in all profiles
    static let defaults: [CommandAction] = [
        .init(title: "Lock Screen", subtitle: "System", kind: .keystroke(key: "q", modifiers: [.command, .control])),
        .init(title: "Screenshot", subtitle: "⌘⇧5", kind: .keystroke(key: "5", modifiers: [.command, .shift])),
        .init(title: "Force Quit", subtitle: "⌘⌥Esc", kind: .shell(command: "")),
    ]
}
