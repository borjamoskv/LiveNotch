import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🔄 Menu Bar Redundancy Manager
// ═══════════════════════════════════════════════════
// When Live Notch shows battery, volume, bluetooth, etc.,
// the macOS menu bar icons become redundant.
// This service hides/restores those system icons.
//
// User request: "implementar redundancias entre Live Notch y MAC
// (desactivar iconos en el MAC)"

@MainActor
final class MenuBarRedundancyManager: ObservableObject {
    static let shared = MenuBarRedundancyManager()
    private let log = NotchLog.make("MenuBarRedundancyManager")
    
    
    // ── Which icons Live Notch is handling ──
    @Published var managingBattery = false {
        didSet { updateRedundancies() }
    }
    @Published var managingBluetooth = false {
        didSet { updateRedundancies() }
    }
    @Published var managingVolume = false {
        didSet { updateRedundancies() }
    }
    @Published var managingWiFi = false {
        didSet { updateRedundancies() }
    }
    @Published var managingClock = false {
        didSet { updateRedundancies() }
    }
    
    // ── Persistence ──
    private let saveKey = "menubar_redundancies"
    
    private init() {
        loadPreferences()
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Hide/Show macOS Menu Bar Icons
    // ═══════════════════════════════════════════════════
    
    /// Toggle a specific system icon's visibility in the menu bar
    /// Uses `defaults write` to control macOS menu extras
    func updateRedundancies() {
        // Battery
        setMenuExtra(
            domain: "com.apple.controlcenter",
            key: "NSStatusItem Visible Battery",
            visible: !managingBattery
        )
        
        // Bluetooth
        setMenuExtra(
            domain: "com.apple.controlcenter",
            key: "NSStatusItem Visible Bluetooth",
            visible: !managingBluetooth
        )
        
        // Sound (Volume)
        setMenuExtra(
            domain: "com.apple.controlcenter",
            key: "NSStatusItem Visible Sound",
            visible: !managingVolume
        )
        
        // WiFi
        setMenuExtra(
            domain: "com.apple.controlcenter",
            key: "NSStatusItem Visible WiFi",
            visible: !managingWiFi
        )
        
        // Clock — handled via system preferences
        if managingClock {
            setMenuExtra(
                domain: "com.apple.controlcenter",
                key: "NSStatusItem Visible Clock",
                visible: false
            )
        }
        
        savePreferences()
        
        // Notify Control Center to refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshSystemUI()
        }
    }
    
    /// Restore ALL macOS menu bar icons (called on app quit)
    func restoreAll() {
        let keys = [
            "NSStatusItem Visible Battery",
            "NSStatusItem Visible Bluetooth",
            "NSStatusItem Visible Sound",
            "NSStatusItem Visible WiFi",
            "NSStatusItem Visible Clock"
        ]
        
        for key in keys {
            setMenuExtra(domain: "com.apple.controlcenter", key: key, visible: true)
        }
        
        refreshSystemUI()
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Private Helpers
    // ═══════════════════════════════════════════════════
    
    private func setMenuExtra(domain: String, key: String, visible: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", domain, key, "-bool", visible ? "true" : "false"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            log.error("Failed to set \(key): \(error.localizedDescription)")
        }
    }
    
    private func refreshSystemUI() {
        // Kill SystemUIServer to force menu bar refresh
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["ControlCenter"]
        
        do {
            try task.run()
        } catch {
            // ControlCenter might not be killable in sandboxed app
            log.warning("Could not restart ControlCenter")
        }
    }
    
    // ── Persistence ──
    private func savePreferences() {
        let prefs: [String: Bool] = [
            "battery": managingBattery,
            "bluetooth": managingBluetooth,
            "volume": managingVolume,
            "wifi": managingWiFi,
            "clock": managingClock
        ]
        NotchPersistence.shared.set(.menuBarRedundancies, value: prefs)
    }
    
    private func loadPreferences() {
        let prefs = NotchPersistence.shared.boolDict(.menuBarRedundancies)
        guard !prefs.isEmpty else { return }
        managingBattery = prefs["battery"] ?? false
        managingBluetooth = prefs["bluetooth"] ?? false
        managingVolume = prefs["volume"] ?? false
        managingWiFi = prefs["wifi"] ?? false
        managingClock = prefs["clock"] ?? false
    }
}
