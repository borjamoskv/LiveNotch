import Foundation
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 💡 TipEngine — Contextual App Intelligence
// ═══════════════════════════════════════════════════
//
// Detects the frontmost macOS application and delivers
// a relevant keyboard shortcut / productivity tip every
// ~10 minutes via the notch's glance HUD.
//
// • Timer resets on app switch (tips always match current app)
// • Seen tips persisted in UserDefaults (survive restart)
// • Pauses when notch is expanded
// • Cycles through all tips before repeating

final class TipEngine: ObservableObject {
    
    // ── Tip Model ──
    
    struct Tip: Identifiable, Equatable {
        let id: String
        let text: String
        let icon: String          // SF Symbol
        let level: Level
        let appName: String       // Human-readable app name
        
        enum Level: String, CaseIterable {
            case beginner
            case intermediate
            case advanced
        }
    }
    
    // ── Public State ──
    
    @Published private(set) var currentTip: Tip?
    @Published private(set) var currentAppName: String = ""
    @Published private(set) var currentBundleID: String = ""
    
    /// Callback for ViewModel integration
    var onTipReady: ((Tip) -> Void)?
    
    /// Pause tip delivery (e.g. when notch is expanded)
    var isPaused: Bool = false
    
    // ── Private ──
    
    private var tipTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let tipInterval: TimeInterval
    private let seenTipsKey = "TipEngine.seenTipIDs"
    
    // ════════════════════════════════════════
    // MARK: - Init
    // ════════════════════════════════════════
    
    /// - Parameter interval: Seconds between tips. Default 600 (10 min).
    init(interval: TimeInterval = 600) {
        self.tipInterval = interval
        observeFrontmostApp()
        startTimer()
    }
    
    deinit {
        tipTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // ════════════════════════════════════════
    // MARK: - App Observation
    // ════════════════════════════════════════
    
    private func observeFrontmostApp() {
        NSWorkspace.shared.publisher(for: \.frontmostApplication)
            .compactMap { $0 }
            .sink { [weak self] app in
                guard let self = self else { return }
                let bundleID = app.bundleIdentifier ?? "unknown"
                let name = app.localizedName ?? "App"
                
                if bundleID != self.currentBundleID {
                    self.currentBundleID = bundleID
                    self.currentAppName = name
                    // Reset timer on app switch so tips match current context
                    self.resetTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    // ════════════════════════════════════════
    // MARK: - Timer Management
    // ════════════════════════════════════════
    
    private func startTimer() {
        tipTimer?.invalidate()
        tipTimer = Timer.scheduledTimer(withTimeInterval: tipInterval, repeats: true) { [weak self] _ in
            self?.deliverTip()
        }
    }
    
    private func resetTimer() {
        startTimer()
    }
    
    private func deliverTip() {
        guard !isPaused else { return }
        guard !currentBundleID.isEmpty else { return }
        
        if let tip = pickTip(for: currentBundleID) {
            DispatchQueue.main.async { [weak self] in
                self?.currentTip = tip
                self?.onTipReady?(tip)
                self?.markAsSeen(tip.id)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Tip Selection
    // ════════════════════════════════════════
    
    private func pickTip(for bundleID: String) -> Tip? {
        // Get tips for this app, fallback to generic
        let appTips = tipDatabase[bundleID] ?? tipDatabase["*"] ?? []
        guard !appTips.isEmpty else { return nil }
        
        let seen = seenTipIDs()
        let unseen = appTips.filter { !seen.contains($0.id) }
        
        // If all seen, reset cycle for this app
        if unseen.isEmpty {
            clearSeenTips(for: bundleID)
            return appTips.randomElement()
        }
        
        return unseen.randomElement()
    }
    
    // ════════════════════════════════════════
    // MARK: - Persistence
    // ════════════════════════════════════════
    
    private func seenTipIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: seenTipsKey) ?? []
        return Set(array)
    }
    
    private func markAsSeen(_ tipID: String) {
        var seen = seenTipIDs()
        seen.insert(tipID)
        UserDefaults.standard.set(Array(seen), forKey: seenTipsKey)
    }
    
    private func clearSeenTips(for bundleID: String) {
        let allTipIDs = Set((tipDatabase[bundleID] ?? []).map(\.id))
        var seen = seenTipIDs()
        seen.subtract(allTipIDs)
        UserDefaults.standard.set(Array(seen), forKey: seenTipsKey)
    }
    
    /// Reset all seen tips (for settings / debug)
    func resetAllSeenTips() {
        UserDefaults.standard.removeObject(forKey: seenTipsKey)
    }
    
    // ════════════════════════════════════════
    // MARK: - 📚 Tip Database
    // ════════════════════════════════════════
    
    private let tipDatabase: [String: [Tip]] = {
        var db: [String: [Tip]] = [:]
        
        // ── Xcode ──
        let xcode = "com.apple.dt.Xcode"
        db[xcode] = [
            Tip(id: "xc01", text: "⌘⇧O — Open Quickly: jump to any file or symbol", icon: "magnifyingglass", level: .beginner, appName: "Xcode"),
            Tip(id: "xc02", text: "⌘B — Build without running to check for errors fast", icon: "hammer.fill", level: .beginner, appName: "Xcode"),
            Tip(id: "xc03", text: "⌃⌘E — Rename refactor: safely rename any symbol across your project", icon: "pencil.line", level: .intermediate, appName: "Xcode"),
            Tip(id: "xc04", text: "⌘⇧J — Reveal current file in the Project Navigator", icon: "folder.fill", level: .beginner, appName: "Xcode"),
            Tip(id: "xc05", text: "⌃I — Re-indent selected code for clean formatting", icon: "text.alignleft", level: .beginner, appName: "Xcode"),
            Tip(id: "xc06", text: "⌘⇧A — Show Quick Actions: AI-powered code actions menu", icon: "wand.and.stars", level: .intermediate, appName: "Xcode"),
            Tip(id: "xc07", text: "⌘⌥[ / ] — Move a line of code up or down", icon: "arrow.up.arrow.down", level: .intermediate, appName: "Xcode"),
            Tip(id: "xc08", text: "⌘⌥/ — Add documentation comment template above a function", icon: "doc.text", level: .intermediate, appName: "Xcode"),
            Tip(id: "xc09", text: "⌃⇧⌘A — Predictive code completion: accept suggestions with Tab", icon: "brain.filled.head.profile", level: .advanced, appName: "Xcode"),
            Tip(id: "xc10", text: "⌘⇧Y — Toggle the Debug Console while running", icon: "terminal.fill", level: .beginner, appName: "Xcode"),
        ]
        
        // ── Finder ──
        let finder = "com.apple.finder"
        db[finder] = [
            Tip(id: "fn01", text: "⌘⇧. — Toggle hidden files visibility", icon: "eye.fill", level: .beginner, appName: "Finder"),
            Tip(id: "fn02", text: "Space — Quick Look: preview any file without opening it", icon: "eye.square.fill", level: .beginner, appName: "Finder"),
            Tip(id: "fn03", text: "⌘⌥P — Show/hide the path bar at the bottom", icon: "point.topleft.down.to.point.bottomright.curvepath", level: .beginner, appName: "Finder"),
            Tip(id: "fn04", text: "⌘⇧G — Go to Folder: type any path to jump there instantly", icon: "folder.badge.gearshape", level: .intermediate, appName: "Finder"),
            Tip(id: "fn05", text: "⌘D — Duplicate selected files", icon: "doc.on.doc.fill", level: .beginner, appName: "Finder"),
            Tip(id: "fn06", text: "⌘⌥I — Show combined info for multiple selected items", icon: "info.circle.fill", level: .intermediate, appName: "Finder"),
            Tip(id: "fn07", text: "⌘⌥V — Move files (cut + paste) instead of copy", icon: "scissors", level: .intermediate, appName: "Finder"),
            Tip(id: "fn08", text: "⌘⇧N — Create a new folder", icon: "folder.badge.plus", level: .beginner, appName: "Finder"),
        ]
        
        // ── Safari ──
        let safari = "com.apple.Safari"
        db[safari] = [
            Tip(id: "sf01", text: "⌘L — Focus the URL bar instantly", icon: "link", level: .beginner, appName: "Safari"),
            Tip(id: "sf02", text: "⌘⇧\\ — Tab overview: see all tabs at a glance", icon: "square.grid.2x2.fill", level: .beginner, appName: "Safari"),
            Tip(id: "sf03", text: "⌘Y — Show full browsing history", icon: "clock.fill", level: .beginner, appName: "Safari"),
            Tip(id: "sf04", text: "⌘⇧R — Reload without cache (force refresh)", icon: "arrow.clockwise", level: .intermediate, appName: "Safari"),
            Tip(id: "sf05", text: "⌘⇧T — Reopen the last closed tab", icon: "arrow.uturn.backward", level: .beginner, appName: "Safari"),
            Tip(id: "sf06", text: "⌘⌥W — Close all tabs except the current one", icon: "xmark.square.fill", level: .intermediate, appName: "Safari"),
            Tip(id: "sf07", text: "⌘D — Add current page to bookmarks", icon: "bookmark.fill", level: .beginner, appName: "Safari"),
            Tip(id: "sf08", text: "⌘, — Open Safari preferences", icon: "gearshape.fill", level: .beginner, appName: "Safari"),
        ]
        
        // ── Terminal ──
        let terminal = "com.apple.Terminal"
        db[terminal] = [
            Tip(id: "tm01", text: "⌃R — Reverse search: find previous commands by typing", icon: "magnifyingglass", level: .intermediate, appName: "Terminal"),
            Tip(id: "tm02", text: "⌘T — Open a new tab in the same directory", icon: "plus.rectangle.fill", level: .beginner, appName: "Terminal"),
            Tip(id: "tm03", text: "⌃A / ⌃E — Jump to start / end of command line", icon: "arrow.left.arrow.right", level: .intermediate, appName: "Terminal"),
            Tip(id: "tm04", text: "⌃U — Clear the current line you're typing", icon: "delete.left.fill", level: .intermediate, appName: "Terminal"),
            Tip(id: "tm05", text: "!! — Repeat the last command (bang bang!)", icon: "exclamationmark.2", level: .intermediate, appName: "Terminal"),
            Tip(id: "tm06", text: "⌘K — Clear terminal screen (keeps command history)", icon: "trash.fill", level: .beginner, appName: "Terminal"),
            Tip(id: "tm07", text: "⌃W — Delete the word before the cursor", icon: "delete.backward.fill", level: .advanced, appName: "Terminal"),
            Tip(id: "tm08", text: "open . — Open current directory in Finder", icon: "folder.fill", level: .beginner, appName: "Terminal"),
        ]
        
        // ── VS Code ──
        let vscode = "com.microsoft.VSCode"
        db[vscode] = [
            Tip(id: "vs01", text: "⌘P — Quick Open: jump to any file by name", icon: "doc.text.magnifyingglass", level: .beginner, appName: "VS Code"),
            Tip(id: "vs02", text: "⌘⇧P — Command Palette: access every VS Code command", icon: "terminal.fill", level: .beginner, appName: "VS Code"),
            Tip(id: "vs03", text: "⌥↑ / ⌥↓ — Move selected lines up or down", icon: "arrow.up.arrow.down", level: .intermediate, appName: "VS Code"),
            Tip(id: "vs04", text: "⌘D — Select next occurrence of current word", icon: "text.cursor", level: .intermediate, appName: "VS Code"),
            Tip(id: "vs05", text: "⌘⇧L — Select all occurrences of current selection", icon: "text.magnifyingglass", level: .advanced, appName: "VS Code"),
            Tip(id: "vs06", text: "⌘/ — Toggle line comment", icon: "text.quote", level: .beginner, appName: "VS Code"),
            Tip(id: "vs07", text: "⌃` — Toggle integrated terminal", icon: "terminal", level: .beginner, appName: "VS Code"),
            Tip(id: "vs08", text: "⌘⌥F — Find and replace in current file", icon: "arrow.left.arrow.right", level: .beginner, appName: "VS Code"),
            Tip(id: "vs09", text: "⌘B — Toggle sidebar visibility", icon: "sidebar.left", level: .beginner, appName: "VS Code"),
            Tip(id: "vs10", text: "⌘K ⌘S — Open keyboard shortcuts editor", icon: "keyboard.fill", level: .advanced, appName: "VS Code"),
        ]
        
        // ── Figma ──
        let figma = "com.figma.Desktop"
        db[figma] = [
            Tip(id: "fg01", text: "⌘/ — Quick actions: search any command or plugin", icon: "magnifyingglass", level: .beginner, appName: "Figma"),
            Tip(id: "fg02", text: "I — Eyedropper: sample any color on canvas", icon: "eyedropper.halffull", level: .beginner, appName: "Figma"),
            Tip(id: "fg03", text: "⌥ + Drag — Duplicate any element by dragging", icon: "doc.on.doc.fill", level: .beginner, appName: "Figma"),
            Tip(id: "fg04", text: "⌘G — Group selected layers", icon: "square.3.layers.3d", level: .beginner, appName: "Figma"),
            Tip(id: "fg05", text: "⌘⇧H — Toggle layout grids visibility", icon: "grid", level: .intermediate, appName: "Figma"),
            Tip(id: "fg06", text: "⌘⌥C / ⌘⌥V — Copy and paste styles between elements", icon: "paintbrush.fill", level: .intermediate, appName: "Figma"),
            Tip(id: "fg07", text: "⇧A — Create Auto Layout on selected frames", icon: "arrow.up.and.down.and.arrow.left.and.right", level: .intermediate, appName: "Figma"),
            Tip(id: "fg08", text: "⌘\\ — Toggle UI: hide all panels for distraction-free design", icon: "eye.slash.fill", level: .intermediate, appName: "Figma"),
        ]
        
        // ── Spotify ──
        let spotify = "com.spotify.client"
        db[spotify] = [
            Tip(id: "sp01", text: "Space — Play / Pause current track", icon: "playpause.fill", level: .beginner, appName: "Spotify"),
            Tip(id: "sp02", text: "⌘↑ / ⌘↓ — Volume up / down", icon: "speaker.wave.2.fill", level: .beginner, appName: "Spotify"),
            Tip(id: "sp03", text: "⌘→ / ⌘← — Next / Previous track", icon: "forward.fill", level: .beginner, appName: "Spotify"),
            Tip(id: "sp04", text: "⌘L — Search: jump to the search bar", icon: "magnifyingglass", level: .beginner, appName: "Spotify"),
            Tip(id: "sp05", text: "⌘S — Save current song to your library", icon: "heart.fill", level: .beginner, appName: "Spotify"),
            Tip(id: "sp06", text: "⌘R — Toggle repeat mode (off → all → one)", icon: "repeat", level: .beginner, appName: "Spotify"),
            Tip(id: "sp07", text: "⌘⇧→ — Seek forward in current track", icon: "goforward.15", level: .intermediate, appName: "Spotify"),
            Tip(id: "sp08", text: "⌃⌘F — Toggle fullscreen mode", icon: "arrow.up.left.and.arrow.down.right", level: .beginner, appName: "Spotify"),
        ]
        
        // ── Generic (Fallback) ──
        db["*"] = [
            Tip(id: "gn01", text: "⌘Space — Spotlight: search apps, files, calculations, anything", icon: "magnifyingglass", level: .beginner, appName: "macOS"),
            Tip(id: "gn02", text: "⌘⇥ — Switch between open applications", icon: "rectangle.on.rectangle", level: .beginner, appName: "macOS"),
            Tip(id: "gn03", text: "⌘, — Open Preferences for almost any app", icon: "gearshape.fill", level: .beginner, appName: "macOS"),
            Tip(id: "gn04", text: "⌘⌥Esc — Force Quit: close frozen apps", icon: "xmark.octagon.fill", level: .beginner, appName: "macOS"),
            Tip(id: "gn05", text: "⌃⌘Q — Lock your screen instantly", icon: "lock.fill", level: .beginner, appName: "macOS"),
            Tip(id: "gn06", text: "⌘⇧5 — Screenshot toolbar: capture screen, window, or record", icon: "camera.fill", level: .intermediate, appName: "macOS"),
            Tip(id: "gn07", text: "⌘⇧4, then Space — Screenshot a specific window with shadow", icon: "camera.viewfinder", level: .intermediate, appName: "macOS"),
            Tip(id: "gn08", text: "⌃↑ — Mission Control: see all windows and desktops", icon: "rectangle.3.group.fill", level: .beginner, appName: "macOS"),
            Tip(id: "gn09", text: "⌘⌃Space — Emoji & Symbols picker in any text field", icon: "face.smiling.fill", level: .beginner, appName: "macOS"),
            Tip(id: "gn10", text: "Double-tap ⌘ — Writing Tools: rewrite, proofread, summarize text", icon: "wand.and.stars", level: .intermediate, appName: "macOS"),
        ]
        
        return db
    }()
}
