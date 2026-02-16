import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📺 Fullscreen Detector
// ═══════════════════════════════════════════════════
// Hides notch when streaming apps are fullscreen — Feature #239

final class FullscreenDetector: ObservableObject {
    static let shared = FullscreenDetector()
    
    @Published var isFullscreenActive = false
    @Published var fullscreenApp: String = ""
    
    // Apps where we should hide the notch in fullscreen
    private let streamingApps: Set<String> = [
        "com.google.Chrome", "org.mozilla.firefox", "com.apple.Safari",
        "com.apple.TV", "tv.plex.player", "com.netflix.Netflix",
        "com.spotify.client", "com.apple.iWork.Keynote"
    ]
    
    private var timer: Timer?
    
    private init() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.check()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func check() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let screen = NSScreen.main else { return }
            
            let screenFrame = screen.frame
            var isFS = false
            var fsApp = ""
            
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let bundleID = frontApp.bundleIdentifier ?? ""
                let appName = frontApp.localizedName ?? ""
                
                let options = NSApp.presentationOptions
                if options.contains(.fullScreen) || options.contains(.autoHideMenuBar) {
                    isFS = true
                    fsApp = appName
                }
                
                if self.streamingApps.contains(bundleID) {
                    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
                    for window in windowList {
                        if let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                           ownerPID == frontApp.processIdentifier,
                           let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                            let w = bounds["Width"] ?? 0
                            let h = bounds["Height"] ?? 0
                            if w >= screenFrame.width && h >= screenFrame.height {
                                isFS = true
                                fsApp = appName
                                break
                            }
                        }
                    }
                }
            }
            
            if isFS != self.isFullscreenActive {
                self.isFullscreenActive = isFS
                self.fullscreenApp = fsApp
            }
        }
    }
}
