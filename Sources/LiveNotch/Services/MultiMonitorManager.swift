import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🖥️ Multi-Monitor Manager
// ═══════════════════════════════════════════════════
// Feature #142 — User can choose which screen the notch appears on

final class MultiMonitorManager: ObservableObject {
    static let shared = MultiMonitorManager()
    
    @Published var screens: [ScreenInfo] = []
    @Published var selectedScreenIndex: Int = 0
    
    struct ScreenInfo: Identifiable {
        let id: Int
        let name: String
        let frame: NSRect
        let hasNotch: Bool
        let isMain: Bool
    }
    
    private var observer: Any?
    
    private init() {
        refreshScreens()
        
        // Listen for screen changes (plug/unplug monitors)
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshScreens()
        }
    }
    
    func refreshScreens() {
        screens = NSScreen.screens.enumerated().map { (idx, screen) in
            let name = screen.localizedName
            let sf = screen.frame
            let vf = screen.visibleFrame
            let menuBarHeight = sf.height - vf.height - vf.origin.y
            let hasNotch = menuBarHeight > 24 // Real notch Macs have >24pt menu bar
            
            return ScreenInfo(
                id: idx,
                name: name,
                frame: sf,
                hasNotch: hasNotch,
                isMain: screen == NSScreen.main
            )
        }
        
        // Auto-select the screen with notch if available
        if let notchIdx = screens.firstIndex(where: { $0.hasNotch }) {
            selectedScreenIndex = notchIdx
        }
    }
    
    var selectedScreen: NSScreen? {
        guard selectedScreenIndex < NSScreen.screens.count else { return NSScreen.main }
        return NSScreen.screens[selectedScreenIndex]
    }
    
    func selectScreen(_ index: Int) {
        guard index < screens.count else { return }
        selectedScreenIndex = index
        HapticManager.shared.play(.toggle)
    }
}
