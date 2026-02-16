import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 🗄️ NotchPersistence — Centralized State Store
// ═══════════════════════════════════════════════════
// Phase 6 MEJORAlo: Replaces 39+ scattered UserDefaults calls
// with a type-safe, atomic, debounced persistence layer.
//
// Features:
//  • Type-safe keys (no string literals)
//  • Atomic file writes (crash-resilient)
//  • Debounced saves (coalesces rapid changes) — cancellable DispatchWorkItem
//  • SavePriority: .critical = write-through, .deferred = debounced 500ms
//  • Auto-migration with backup/rollback from legacy UserDefaults
//  • Corruption recovery from .backup file
//  • Cortex-backed file storage (~/.cortex/livenotch/)

final class NotchPersistence {
    static let shared = NotchPersistence()
    private let log = NotchLog.make("NotchPersistence")
    
    
    // ── Keys ──
    enum Key: String, CaseIterable {
        // Core UI
        case chameleonEnabled
        case liquidGlass
        case notchTheme
        case hapticEnabled
        
        // Geometry (@AppStorage stays in LiveNotch.swift — those are SwiftUI-bound)
        // notchWidth, notchHeight, wingContentWidth, cornerRad, topOffset
        
        // Services (migrated from individual managers)
        case gestureEyeEnabled
        case relayBaseURL     = "notch.relay.base_url"
        case relayDeviceToken = "notch.relay.device_token"
        case relayApiKey      = "notch.relay.api_key"
        case rescueTimeApiKey = "notch.rescuetime.api_key"
        
        // Secondary services
        case excludedApps       = "excluded_apps"
        case menuBarRedundancies = "menubar_redundancies"
        case seenTipIDs         = "TipEngine.seenTipIDs"
        
        // Codable data services (stored as base64)
        case vaultItems         = "notch_vault_items"
        case brainDumpItems     = "braindump_items"
        case quickNotes         = "quicknotes_items"
        case scriptHistory      = "script_history"
        case pinnedApps         = "quicklaunch_pinned"
        
        // AI / Evolution
        case evolutionGenome    = "evolution_genome"
        
        // User Profile
        case userProfileAccent  = "user_profile_accent"
    }
    
    // ── Save Priority ──
    enum SavePriority { case critical, deferred }
    
    // ── State ──
    private var store: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.moskv.livenotch.persistence", qos: .utility)
    private var pendingSave: DispatchWorkItem?   // Fix: cancellable replaces bool flag
    private let debounceInterval: TimeInterval = 0.5
    
    // ── Paths ──
    private let cortexDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cortex/livenotch", isDirectory: true)
    }()
    
    private var stateFilePath: URL {
        cortexDir.appendingPathComponent("notch-state.json")
    }
    
    private let migrationKey = "notchPersistence.migrated.v1"
    
    // ═══════════════════════════════════════
    // MARK: - Init
    // ═══════════════════════════════════════
    
    private init() {
        ensureDirectory()
        loadState()
        migrateIfNeeded()
    }
    
    // ═══════════════════════════════════════
    // MARK: - Public API
    // ═══════════════════════════════════════
    
    /// Read a value for a key (type-safe).
    func get<T>(_ key: Key) -> T? {
        queue.sync {
            store[key.rawValue] as? T
        }
    }
    
    /// Read a Bool with a default value.
    func bool(_ key: Key, default defaultValue: Bool = false) -> Bool {
        get(key) ?? defaultValue
    }
    
    /// Read a String with a default value.
    func string(_ key: Key, default defaultValue: String = "") -> String {
        get(key) ?? defaultValue
    }
    
    /// Read a string array.
    func stringArray(_ key: Key) -> [String] {
        get(key) ?? []
    }
    
    /// Read a [String: Bool] dictionary.
    func boolDict(_ key: Key) -> [String: Bool] {
        get(key) ?? [:]
    }
    
    /// Store a Codable value as base64 string.
    /// Codable data is always saved with `.critical` priority (user data).
    func setCodable<T: Encodable>(_ key: Key, value: T?) {
        guard let value = value,
              let data = try? JSONEncoder().encode(value) else {
            set(key, value: nil, priority: .critical)
            return
        }
        set(key, value: data.base64EncodedString(), priority: .critical)
    }
    
    /// Read a Codable value from base64 string.
    func getCodable<T: Decodable>(_ key: Key, as type: T.Type) -> T? {
        guard let b64: String = get(key),
              let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    /// Write a value. `.critical` = immediate write-through, `.deferred` = debounced 500ms.
    func set(_ key: Key, value: Any?, priority: SavePriority = .deferred) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let value = value {
                self.store[key.rawValue] = value
            } else {
                self.store.removeValue(forKey: key.rawValue)
            }
            switch priority {
            case .critical:
                self.pendingSave?.cancel()
                self.pendingSave = nil
                self.performSave()
            case .deferred:
                self.scheduleSave()
            }
        }
    }
    
    /// Force an immediate save (use on app termination).
    func flush() {
        queue.sync {
            self.performSave()
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Persistence Engine
    // ═══════════════════════════════════════
    
    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: cortexDir, withIntermediateDirectories: true)
    }
    
    private func loadState() {
        queue.sync {
            guard FileManager.default.fileExists(atPath: stateFilePath.path) else { return }
            do {
                let data = try Data(contentsOf: stateFilePath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    store = json
                    log.info("Loaded \(store.count) keys")
                }
            } catch {
                log.error("Load failed — \(error.localizedDescription), attempting recovery")
                recoverFromCorruption()
            }
        }
    }
    
    private func recoverFromCorruption() {
        let backupPath = stateFilePath.appendingPathExtension("backup")
        if FileManager.default.fileExists(atPath: backupPath.path),
           let data = try? Data(contentsOf: backupPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            store = json
            log.info("Recovered \(store.count) keys from backup")
            return
        }
        store = [:]
        log.info("No backup available, starting fresh")
    }
    
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingSave = nil
            self.performSave()
        }
        pendingSave = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
    
    private func performSave() {
        do {
            let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
            // Rotate backup before overwrite
            let backupPath = stateFilePath.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: stateFilePath.path) {
                try? FileManager.default.removeItem(at: backupPath)
                try? FileManager.default.copyItem(at: stateFilePath, to: backupPath)
            }
            try data.write(to: stateFilePath, options: .atomic)
        } catch {
            log.error("Save failed — \(error.localizedDescription)")
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Migration from UserDefaults
    // ═══════════════════════════════════════
    
    private func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        log.info("Migrating from UserDefaults...")
        
        // Backup state before migration for rollback
        let backupPath = stateFilePath.appendingPathExtension("pre-migration")
        if FileManager.default.fileExists(atPath: stateFilePath.path) {
            try? FileManager.default.removeItem(at: backupPath)
            try? FileManager.default.copyItem(at: stateFilePath, to: backupPath)
        }
        let snapshotStore = store  // In-memory snapshot for rollback
        
        let defaults = UserDefaults.standard
        
        // Bool migrations
        let boolKeys: [(Key, String, Bool)] = [
            (.chameleonEnabled, "chameleonEnabled", true),
            (.liquidGlass, "liquidGlass", false),
            (.hapticEnabled, "hapticEnabled", true),
            (.gestureEyeEnabled, "gestureEyeEnabled", false),
        ]
        
        for (key, legacyKey, fallback) in boolKeys {
            let value = defaults.object(forKey: legacyKey) as? Bool ?? fallback
            store[key.rawValue] = value
        }
        
        // Array migrations
        if let excludedApps = defaults.stringArray(forKey: "excluded_apps") {
            store[Key.excludedApps.rawValue] = excludedApps
        }
        if let seenTips = defaults.stringArray(forKey: "TipEngine.seenTipIDs") {
            store[Key.seenTipIDs.rawValue] = seenTips
        }
        
        // Dict migrations
        if let menuPrefs = defaults.dictionary(forKey: "menubar_redundancies") as? [String: Bool] {
            store[Key.menuBarRedundancies.rawValue] = menuPrefs
        }
        
        // String migrations
        let stringKeys: [(Key, String)] = [
            (.notchTheme, "notchTheme"),
            (.relayBaseURL, "notch.relay.base_url"),
            (.relayDeviceToken, "notch.relay.device_token"),
            (.relayApiKey, "notch.relay.api_key"),
            (.rescueTimeApiKey, "notch.rescuetime.api_key"),
        ]
        
        for (key, legacyKey) in stringKeys {
            if let value = defaults.string(forKey: legacyKey) {
                store[key.rawValue] = value
            }
        }
        
        // Attempt atomic save — rollback on failure
        do {
            let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: stateFilePath, options: .atomic)
            defaults.set(true, forKey: migrationKey)
            try? FileManager.default.removeItem(at: backupPath)  // Clean up pre-migration backup
            log.info("Migration complete ✓ (\(store.count) keys)")
        } catch {
            log.error("Migration FAILED — \(error.localizedDescription), rolling back")
            store = snapshotStore  // Restore in-memory state
            if FileManager.default.fileExists(atPath: backupPath.path) {
                try? FileManager.default.removeItem(at: stateFilePath)
                try? FileManager.default.moveItem(at: backupPath, to: stateFilePath)
            }
        }
    }
}
