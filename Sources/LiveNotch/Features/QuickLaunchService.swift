import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🚀 Quick Launch Service
// ═══════════════════════════════════════════════════
// Competitor parity: NotchNook, NotchBox
// Quick access to favorite apps + recent apps from Dock

final class QuickLaunchService: ObservableObject {
    static let shared = QuickLaunchService()
    
    struct LaunchItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let bundleID: String
        let icon: NSImage?
        let url: URL?
        
        func hash(into hasher: inout Hasher) { hasher.combine(bundleID) }
        static func == (lhs: LaunchItem, rhs: LaunchItem) -> Bool { lhs.bundleID == rhs.bundleID }
    }
    
    @Published var pinnedApps: [LaunchItem] = []
    @Published var recentApps: [LaunchItem] = []
    
    private let pinnedKey = "QuickLaunch_PinnedBundleIDs"
    
    private init() {
        loadPinnedApps()
        refreshRecentApps()
    }
    
    // ── Public API ──
    
    func launch(_ item: LaunchItem) {
        guard let url = item.url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
        refreshRecentApps()
    }
    
    func pin(_ item: LaunchItem) {
        guard !pinnedApps.contains(where: { $0.bundleID == item.bundleID }) else { return }
        pinnedApps.append(item)
        savePinnedApps()
    }
    
    func unpin(_ item: LaunchItem) {
        pinnedApps.removeAll { $0.bundleID == item.bundleID }
        savePinnedApps()
    }
    
    func isPinned(_ bundleID: String) -> Bool {
        pinnedApps.contains { $0.bundleID == bundleID }
    }
    
    func refreshRecentApps() {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .prefix(8)
        
        recentApps = runningApps.compactMap { app in
            guard let bid = app.bundleIdentifier,
                  let url = app.bundleURL else { return nil }
            return LaunchItem(
                name: app.localizedName ?? bid,
                bundleID: bid,
                icon: app.icon,
                url: url
            )
        }
    }
    
    // ── Persistence ──
    
    private func savePinnedApps() {
        let ids = pinnedApps.map { $0.bundleID }
        NotchPersistence.shared.set(.pinnedApps, value: ids)
    }
    
    private func loadPinnedApps() {
        let ids = NotchPersistence.shared.stringArray(.pinnedApps)
        if ids.isEmpty {
            // Default pinned apps
            let defaults = ["com.apple.Safari", "com.apple.mail", "com.apple.Terminal", "com.apple.finder"]
            loadApps(from: defaults)
            return
        }
        loadApps(from: ids)
    }
    
    private func loadApps(from bundleIDs: [String]) {
        pinnedApps = bundleIDs.compactMap { bid in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) else { return nil }
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            return LaunchItem(name: name, bundleID: bid, icon: icon, url: url)
        }
    }
}
