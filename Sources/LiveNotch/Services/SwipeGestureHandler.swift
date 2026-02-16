import AppKit

// ═══════════════════════════════════════════════════
// MARK: - ✋ Swipe Gesture Handler
// ═══════════════════════════════════════════════════
// Swipe left/right = prev/next track
// Swipe up = expand | Swipe down = collapse

final class SwipeGestureHandler {
    static let shared = SwipeGestureHandler()
    
    enum SwipeAction {
        case nextTrack
        case prevTrack
        case expand
        case collapse
    }
    
    var onSwipe: ((SwipeAction) -> Void)?
    
    private var scrollDeltaX: CGFloat = 0
    private var scrollDeltaY: CGFloat = 0
    private var scrollTimer: Timer?
    private var monitor: Any?
    
    private init() {}
    
    deinit {
        scrollTimer?.invalidate()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func startMonitoring(in window: NSWindow) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            
            guard event.window == window else { return event }
            
            self.scrollDeltaX += event.scrollingDeltaX
            self.scrollDeltaY += event.scrollingDeltaY
            
            self.scrollTimer?.invalidate()
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                self.processSwipe()
            }
            
            return event
        }
    }
    
    private func processSwipe() {
        let threshold: CGFloat = 30
        
        if abs(scrollDeltaX) > abs(scrollDeltaY) {
            if scrollDeltaX > threshold {
                onSwipe?(.prevTrack)
                HapticManager.shared.play(.toggle)
            } else if scrollDeltaX < -threshold {
                onSwipe?(.nextTrack)
                HapticManager.shared.play(.toggle)
            }
        } else {
            if scrollDeltaY > threshold {
                onSwipe?(.expand)
                HapticManager.shared.play(.expand)
            } else if scrollDeltaY < -threshold {
                onSwipe?(.collapse)
                HapticManager.shared.play(.collapse)
            }
        }
        
        scrollDeltaX = 0
        scrollDeltaY = 0
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
