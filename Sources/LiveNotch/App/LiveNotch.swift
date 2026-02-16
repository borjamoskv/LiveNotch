import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - NOTCH//WINGS 🕳️⚡ — App Entry
// ═══════════════════════════════════════════════════

@main
struct LiveNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

// ═══════════════════════════════════════════════════
// MARK: - App Delegate
// ═══════════════════════════════════════════════════

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindow: NSWindow?
    var statusItem: NSStatusItem?
    let viewModel = NotchViewModel()
    
    var hotkeyMonitor: Any?
    private var sleepObserver: Any?
    private var wakeObserver: Any?
    private var fullscreenObserver: Any?
    private var screenObserver: Any?
    private var spaceObserver: Any?
    
    // Reactive Geometry
    private var geometryCancellable: AnyCancellable?
    
    // ⚔️ Jedi Mode (Spatial Gestures)
    private var gestureCancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        createNotchWindow()
        createStatusItem()
        setupGlobalHotkeys()
        setupSleepWakeRecovery()
        setupFullscreenDetection()
        setupScreenObservers()
        
        // Initialize essential services immediately
        _ = SmartPolling.shared
        _ = MultiMonitorManager.shared
        _ = AppExclusionManager.shared  // PERF: was initialized TWICE (bug)
        ProfileManager.shared.start()
        
        // PERF: Defer non-essential services — don't block launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            _ = BluetoothMonitor.shared
            _ = BrainDumpManager.shared
            _ = PerAppVolumeMixer.shared
        }
        
        // Start Jedi Engine (Spatial Gestures) - DEFERRED (Zero Permission Rule)
        // let spatialEngine = SpatialGestureEngine.shared
        // spatialEngine.start()
        
        /*
        gestureCancellable = spatialEngine.$activeAction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self = self else { return }
                switch action {
                case .pinch:
                    // "Force Pull" the notch open
                    if !self.viewModel.isExpanded {
                        withAnimation(DS.Anim.springSoft) {
                            self.viewModel.isExpanded = true
                        }
                        HapticManager.shared.play(.heavy)
                    }
                case .swipeLeft:
                    // Dismiss / Next
                    if self.viewModel.isExpanded {
                        withAnimation { self.viewModel.isExpanded = false }
                    } else {
                        self.viewModel.nextTrack()
                    }
                case .swipeRight:
                    self.viewModel.previousTrack()
                case .palm:
                    self.viewModel.togglePlayPause()
                case .none:
                    break
                }
            }
         */
        
        // Swipe gestures
        if let w = self.notchWindow {
            SwipeGestureHandler.shared.startMonitoring(in: w)
            SwipeGestureHandler.shared.onSwipe = { [weak self] action in
                DispatchQueue.main.async {
                    guard let vm = self?.viewModel else { return }
                    switch action {
                    case .nextTrack: vm.nextTrack()
                    case .prevTrack: vm.previousTrack()
                    case .expand:
                        withAnimation(DS.Anim.springStd) {
                            vm.isExpanded = true
                        }
                    case .collapse:
                        withAnimation(DS.Anim.springStd) {
                            vm.isExpanded = false
                            vm.isMirrorActive = false
                            vm.isClipboardVisible = false
                            vm.isBrainDumpVisible = false
                            vm.isVolumeMixerVisible = false
                            vm.showVolumeSlider = false
                        }
                    }
                }
            }
        }
        
        NSLog("🕳️⚡ NOTCH//WINGS ready — borderless overlay on physical notch")
    }
    
    // ════════════════════════════════════════
    // MARK: - Window (Borderless Overlay on Physical Notch)
    // ════════════════════════════════════════
    // The ONLY correct approach for a notch overlay app:
    // 1. Borderless window at screen top
    // 2. Black background that visually merges with the physical notch
    // 3. Wings positioned using auxiliaryTopLeftArea / auxiliaryTopRightArea
    // 4. Expanded panel drops below the notch
    //
    // NSTitlebarAccessoryViewController does NOT work for overlays —
    // it only works for a window's own titlebar, not the screen's notch.
    
    func createNotchWindow() {
        guard let screen = MultiMonitorManager.shared.selectedScreen ?? NSScreen.main else { return }
        let sf = screen.frame
        let geo = NotchGeometry.shared
        
        // Get exact notch dimensions from macOS APIs
        let notchHeight = screen.safeAreaInsets.top
        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea
        
        // Calculate notch geometry — guard against NaN (§3.1 CALayerInvalidGeometry)
        let notchWidth: CGFloat
        let notchCenterX: CGFloat  // Global X coordinate of notch center
        if let al = auxLeft, let ar = auxRight, ar.minX > al.maxX {
            notchWidth = floor(ar.minX - al.maxX) // floor() prevents sub-pixel NaN
            // Notch center = midpoint between right edge of left area and left edge of right area
            // auxiliaryTopLeftArea/auxiliaryTopRightArea are in GLOBAL screen coordinates
            notchCenterX = (al.maxX + ar.minX) / 2.0
            
            // Geometry captured — auxLeft/auxRight measured
        } else {
            notchWidth = 200
            // Fallback: center of screen
            notchCenterX = sf.origin.x + sf.width / 2.0
        }
        
        // Safety: abort if geometry is invalid (screen disconnected mid-transition)
        guard notchWidth > 0, sf.width > 0, sf.height > 0 else {
            NSLog("⚠️ Invalid screen geometry — skipping window creation")
            return
        }
        
        // Wing content width — clamped to available space so we never cover
        // macOS menu bar icons. auxLeft/auxRight report total area, but icons
        // already occupy some of that space, so we subtract a safety margin.
        let maxWingWidth: CGFloat = 60
        let safetyMargin: CGFloat = 20 // Extra margin to avoid overlapping icons
        let leftAvailable: CGFloat = max(0, (auxLeft?.size.width ?? maxWingWidth) - safetyMargin)
        let rightAvailable: CGFloat = max(0, (auxRight?.size.width ?? maxWingWidth) - safetyMargin)
        let wingContentWidth: CGFloat = min(maxWingWidth, leftAvailable, rightAvailable)
        
        // Window dimensions
        let windowWidth = wingContentWidth + notchWidth + wingContentWidth
        
        // ── SYNC NotchGeometry with real measured values ──
        // This ensures SwiftUI views use screen-accurate dimensions,
        // not stale @AppStorage defaults (which can diverge heavily).
        geo.notchWidth = Double(notchWidth)
        geo.wingContentWidth = Double(wingContentWidth)
        if notchHeight > 0 {
            geo.notchHeight = Double(notchHeight)
        }
        
        // ── CENTER WINDOW ON THE PHYSICAL NOTCH ──
        // notchCenterX is the global X midpoint of the physical notch.
        // Place window so its center aligns with notchCenterX.
        let windowX = notchCenterX - windowWidth / 2.0
        let windowHeight: CGFloat = 380
        
        // Geometry sync complete
        
        // Adaptation: if screen has no physical notch, we enter "Floating Island" mode.
        // We offset the window slightly from the top to appear as a floating pill.
        let hasPhysicalNotch = MultiMonitorManager.shared.screens.first(where: { $0.id == MultiMonitorManager.shared.selectedScreenIndex })?.hasNotch ?? true
        viewModel.isFloating = !hasPhysicalNotch
        
        let floatingOffset: CGFloat = viewModel.isFloating ? 12 : 0
        

        
        let window = NotchWindow(
            contentRect: NSRect(
                x: windowX,
                y: sf.origin.y + sf.height - windowHeight - floatingOffset,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Overlay behavior
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .statusBar // 🛡️ Kimi: Ensure we are on the same Z-plane as the menu bar
        
        // Critical for "Always Active" feel
        window.hidesOnDeactivate = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        
        // ── SwiftUI content with notch geometry ──
        let view = NotchView(viewModel: viewModel, geometry: geo)
        // PassthroughHostingView: clicks on transparent Spacer area fall through
        let hostingView = PassthroughHostingView(rootView: view)
        
        // Critical: Dynamic Hit Test to prevent blocking standard Menu Bar
        hostingView.shouldCapture = { [weak self] point, viewBounds in
            guard let self = self else { return false }
            let vm = self.viewModel
            let distanceFromTop = viewBounds.height - point.y
            
            // If dragging a file, always capture (to allow drop)
            if vm.isHovering { return true }
            
            // If expanded, capture almost everything
            if vm.isExpanded {
                return distanceFromTop <= 360
            }
            
            // If collapsed, ONLY capture the notch height
            let notchH = geo.notchHeight
            return distanceFromTop <= (notchH + 4)
        }
        
        window.contentView = hostingView
        window.orderFrontRegardless()
        self.notchWindow = window
        
        // Window created and ordered front
        
        // Subscribe to Geometry Changes (God Mode)
        geometryCancellable = geo.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateWindowFrame()
                }
            }
    }
    
    func updateWindowFrame() {
        guard let window = notchWindow, let screen = window.screen else { return }
        
        // 🛡️ Kimi: Re-evaluate notch state dynamically
        // If we just exited fullscreen, we might have lost track of the notch or screen mode changed.
        let hasNotch = (screen.auxiliaryTopLeftArea != nil) || (screen.safeAreaInsets.top > 20)
        viewModel.isFloating = !hasNotch
        
        let geo = NotchGeometry.shared
        let sf = screen.frame
        
        // Re-calculate actual geometry from screen APIs (same logic as createNotchWindow)
        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea
        
        let notchWidth: CGFloat
        let notchCenterX: CGFloat
        if let al = auxLeft, let ar = auxRight, ar.minX > al.maxX {
            notchWidth = floor(ar.minX - al.maxX)
            notchCenterX = (al.maxX + ar.minX) / 2.0
        } else {
            notchWidth = CGFloat(geo.notchWidth)
            notchCenterX = sf.origin.x + sf.width / 2.0
        }
        
        let maxWingWidth: CGFloat = 60
        let safetyMargin: CGFloat = 20
        let leftAvailable: CGFloat = max(0, (auxLeft?.size.width ?? maxWingWidth) - safetyMargin)
        let rightAvailable: CGFloat = max(0, (auxRight?.size.width ?? maxWingWidth) - safetyMargin)
        let wingContentWidth: CGFloat = min(maxWingWidth, leftAvailable, rightAvailable)
        
        let windowWidth = wingContentWidth + notchWidth + wingContentWidth
        
        // Center window on the physical notch
        let windowX = notchCenterX - windowWidth / 2.0
        let floatingOffset: CGFloat = viewModel.isFloating ? 12 : 0
        let topY = sf.origin.y + sf.height - geo.expandedHeight + CGFloat(geo.topOffset) - floatingOffset
        
        let newFrame = NSRect(
            x: windowX, 
            y: topY, 
            width: windowWidth, 
            height: geo.expandedHeight
        )
        

        window.setFrame(newFrame, display: true, animate: false)
    }
    
    // ════════════════════════════════════════
    // MARK: - Menu Bar Status Item
    // ════════════════════════════════════════
    
    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🕳️"
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "NOTCH//WINGS ⚡", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        
        let expandItem = NSMenuItem(title: "Toggle Panel", action: #selector(toggleNotch), keyEquivalent: "n")
        expandItem.keyEquivalentModifierMask = NSEvent.ModifierFlags([.command, .shift])
        menu.addItem(expandItem)
        
        let monitorMenu = NSMenu()
        for (idx, screen) in MultiMonitorManager.shared.screens.enumerated() {
            let label = "\(screen.name)\(screen.hasNotch ? " (notch)" : "")\(screen.isMain ? " ★" : "")"
            let item = NSMenuItem(title: label, action: #selector(selectMonitor(_:)), keyEquivalent: "")
            item.tag = idx
            item.state = idx == MultiMonitorManager.shared.selectedScreenIndex ? .on : .off
            monitorMenu.addItem(item)
        }
        let monitorItem = NSMenuItem(title: "🖥️ Monitor", action: nil, keyEquivalent: "")
        monitorItem.submenu = monitorMenu
        menu.addItem(monitorItem)
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // ════════════════════════════════════════
    // MARK: - Global Hotkeys
    // ════════════════════════════════════════
    
    func setupGlobalHotkeys() {
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // ⌘⇧N — Toggle panel
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 45 {
                DispatchQueue.main.async { self.viewModel.isExpanded.toggle() }
            }
            // ⌘⇧M — Mirror
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 {
                DispatchQueue.main.async { self.viewModel.isMirrorActive.toggle() }
            }
            // ⌘⇧B — Brain dump
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 11 {
                DispatchQueue.main.async {
                    self.viewModel.isBrainDumpVisible.toggle()
                    if self.viewModel.isBrainDumpVisible { self.viewModel.isExpanded = true }
                    HapticManager.shared.play(.toggle)
                }
            }
            // ⌘⇧E — Eye Control toggle
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 14 {
                DispatchQueue.main.async {
                    self.toggleEyeControl()
                }
            }
            // ⌘⇧H — Hide/Show Notch (Zen Mode)
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 4 { // 'H' key code is 4
                DispatchQueue.main.async {
                    self.viewModel.toggleNotchVisibility()
                    self.createStatusItem() // Update menu text
                }
            }
            // ⌘⇧6 — Color Picker
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 22 { // '6' key code is 22
                DispatchQueue.main.async {
                    self.viewModel.activateColorPicker()
                }
            }
            // ⌥Space — Command Palette
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                DispatchQueue.main.async {
                    self.viewModel.isExpanded.toggle()
                    HapticManager.shared.play(.toggle)
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Actions
    // ════════════════════════════════════════
    
    @MainActor @objc func toggleNotch() { viewModel.isExpanded.toggle() }
    
    /// Eye-tracking control toggle — stub for future implementation
    @MainActor func toggleEyeControl() {
        // TODO: Implement eye-tracking control toggle
        HapticManager.shared.play(.toggle)
    }
    
    @MainActor @objc func selectMonitor(_ sender: NSMenuItem) {
        MultiMonitorManager.shared.selectScreen(sender.tag)
        notchWindow?.close()
        createNotchWindow()
        createStatusItem()
    }
    
    @MainActor @objc func quitApp() { NSApp.terminate(nil) }
    
    // ════════════════════════════════════════
    // MARK: - Sleep/Wake Recovery
    // ════════════════════════════════════════
    
    func setupSleepWakeRecovery() {
        let ws = NSWorkspace.shared.notificationCenter
        
        sleepObserver = ws.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
             Task { @MainActor [weak self] in
                 self?.viewModel.isExpanded = false
             }
        }
        
        wakeObserver = ws.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Task { @MainActor [weak self] in
                    self?.notchWindow?.close()
                    self?.createNotchWindow()
                    self?.viewModel.startNowPlayingMonitor()
                    self?.viewModel.updateBattery()
                    self?.viewModel.updateVolume()
                    MultiMonitorManager.shared.refreshScreens()
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Fullscreen Detection
    // ════════════════════════════════════════
    
    func setupFullscreenDetection() {
        fullscreenObserver = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if FullscreenDetector.shared.isFullscreenActive {
                    self.notchWindow?.alphaValue = 0
                } else if self.notchWindow?.alphaValue == 0 {
                    self.notchWindow?.alphaValue = 1
                    // Reposition after fullscreen exit — screen frame may have shifted
                    self.updateWindowFrame()
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Screen & Space Change Observers
    // ════════════════════════════════════════
    
    func setupScreenObservers() {
        // Reposition window when display configuration changes (resolution, arrangement, connect/disconnect)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Small delay to let macOS finish the screen transition animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateWindowFrame()
            }
        }
        
        // Reposition when switching spaces (e.g., entering/exiting fullscreen apps)
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Longer delay — macOS space transition animation takes ~0.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.updateWindowFrame()
            }
        }
    }
    
    // §2.1 Security: Prevent code injection via saved state deserialization (CVE-2021-30873)
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = hotkeyMonitor { NSEvent.removeMonitor(monitor) }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Notch Geometry (passed to SwiftUI)
// ═══════════════════════════════════════════════════

class NotchGeometry: ObservableObject {
    static let shared = NotchGeometry()
    
    // Configurable Geometry (God Mode)
    @AppStorage("notchWidth") var notchWidth: Double = 188.0
    @AppStorage("notchHeight") var notchHeight: Double = 32.0
    @AppStorage("wingContentWidth") var wingContentWidth: Double = 200.0
    @AppStorage("cornerRad") var cornerRadius: Double = 12.0 // Device dependent usually
    @AppStorage("topOffset") var topOffset: Double = 0.0
    
    // Computed for Layout
    var windowWidth: CGFloat { (CGFloat(wingContentWidth) * 2) + CGFloat(notchWidth) }
    var collapsedHeight: CGFloat { CGFloat(notchHeight) }
    let expandedHeight: CGFloat = 380.0
}

// ═══════════════════════════════════════════════════
// MARK: - NotchWindow (borderless + click support)
// ═══════════════════════════════════════════════════

class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Accept clicks even when this window isn't active/key
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            self.makeKeyAndOrderFront(nil)
        }
        super.sendEvent(event)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - PassthroughHostingView (click-through transparent areas)
// ═══════════════════════════════════════════════════
// Clicks on transparent areas fall through to apps below.
// Only opaque/colored SwiftUI content captures mouse events.

class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var shouldCapture: ((NSPoint, NSRect) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        
        // Use the closure if provided
        if let captureStrategy = shouldCapture {
            if !captureStrategy(point, bounds) {
                return nil // Pass through to system (Menu Bar, underlying windows)
            }
        } else {
             // Fallback: Default to top area if no strategy
             let distanceFromTop = bounds.height - point.y
             if distanceFromTop > 350 { return nil }
        }
        
        // First: check if SwiftUI found a specific interactive subview
        if let result = super.hitTest(point), result !== self {
            return result
        }
        
        return self // Capture click
    }
}
