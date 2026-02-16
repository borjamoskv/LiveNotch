import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🚫 App Exclusion Manager
// ═══════════════════════════════════════════════════
// Hide notch when specific apps are frontmost

final class AppExclusionManager: ObservableObject {
    static let shared = AppExclusionManager()
    
    @Published var excludedBundleIDs: Set<String> = []
    @Published var shouldHide = false
    
    private var timer: Timer?
    private let saveKey = "excluded_apps"
    
    private init() {
        loadExclusions()
        
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkFrontApp()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func addExclusion(_ bundleID: String) {
        excludedBundleIDs.insert(bundleID)
        saveExclusions()
    }
    
    func removeExclusion(_ bundleID: String) {
        excludedBundleIDs.remove(bundleID)
        saveExclusions()
    }
    
    func toggleExclusion(_ bundleID: String) {
        if excludedBundleIDs.contains(bundleID) {
            removeExclusion(bundleID)
        } else {
            addExclusion(bundleID)
        }
    }
    
    private func checkFrontApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            shouldHide = false
            return
        }
        shouldHide = excludedBundleIDs.contains(bundleID)
    }
    
    private func saveExclusions() {
        NotchPersistence.shared.set(.excludedApps, value: Array(excludedBundleIDs))
    }
    
    private func loadExclusions() {
        let saved = NotchPersistence.shared.stringArray(.excludedApps)
        if !saved.isEmpty {
            excludedBundleIDs = Set(saved)
        }
    }
    
    /// Get list of running regular apps for UI
    var runningApps: [(name: String, bundleID: String, icon: NSImage?)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return (
                    name: app.localizedName ?? "Unknown",
                    bundleID: bundleID,
                    icon: app.icon
                )
            }
    }
}
