import SwiftUI
import AppKit
import Combine
import UserNotifications

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Notch View Model — The Orchestrator
// ═══════════════════════════════════════════════════
// Refactored: delegates to focused controllers instead of owning everything.
// Before: 850 lines, 50+ @Published properties (God Object)
// After: ~200 lines, pure orchestration + wiring

@MainActor
class NotchViewModel: ObservableObject {
    
    // ── State Machine ──
    enum NotchMode: Equatable {
        case collapsed
        case expanded
        case mirror
        case tray
        case clipboard
        case settings
        case launcher
    }
    
    @Published var mode: NotchMode = .collapsed
    
    // ── Delegated Controllers ──
    @Published var music = MusicController()
    @Published var battery = BatteryMonitor()
    @Published var timerManager = TimerManager()
    @Published var focus = FocusStateMonitor()
    @Published var ai = AIController()
    @Published var swarm = SwarmEngine()
    @Published var tipEngine = TipEngine()
    @Published var bioLum = BioLumEngine()
    @Published var userMode = UserModeManager.shared
    @Published var scriptDrop = ScriptDropService.shared
    @Published var cortex = CortexController()
    
    // ── States ──
    @Published var isExpanded = false
    @Published var isHovering = false
    @Published var isFloating = false // Multi-monitor pill mode
    
    // 🎭 Operation Modes (User Request)
    enum AppMode {
        case beauty     // "Modo Belleza": Aesthetic, minimal, ambient only
        case function   // "Modo Funciones": Tools, telemetry, full info
        case camouflage // "Opción Camuflaje": Native look, hidden until interaction
    }
    @Published var appMode: AppMode = .function
    
    // ── Content States ──
    @Published var isMirrorActive = false
    @Published var isClipboardVisible = false
    @Published var isBrainDumpVisible = false
    @Published var isVolumeMixerVisible = false
    @Published var isEyeControlVisible = false
    @Published var isSettingsVisible = false
    @Published var isQuickLaunchVisible = false
    @Published var isAppLauncherVisible = false
    @Published var isSwarmVisible = false
    @Published var isCalendarVisible = false
    @Published var isModeSelectorVisible = false
    @Published var isScriptDropVisible = false
    @Published var isCortexVisible = false  // 🧠 CORTEX Memory Panel
    @Published var isNotchHidden = false // Zen Mode: Hide notch completely
    @Published var isGodModeVisible = false // 🎛️ Geometry Controls
    @Published var isBlueYLM = false       // 🔵 Blue YInMn Theme
    @Published var isClawBotVisible = false // 🐾 ClawBot AI Panel
    @Published var isEcosystemHubVisible = false // 🍎 Ecosystem Hub (AirPods/Watch)
    @Published var isCompactMode = false // Safety Mode: Shrink wings to avoid menu icons
    @Published var droppedFiles: [URL] = []
    
    // ── Color Picker ──
    @Published var lastCapturedColor: NSColor?
    @Published var showColorFeedback = false
    
    // ── Tip HUD ──
    @Published var tipNotification: TipEngine.Tip? = nil
    @Published var isDropTargetActive: Bool = false
    @Published var isVanguardActive: Bool = false // Telemetry Mode
    @Published var isChronosActive: Bool = false // Focus Timer Mode
    
    // ── Liquid Glass ──
    @Published var isLiquidGlassEnabled: Bool = NotchPersistence.shared.bool(.liquidGlass) {
        didSet { NotchPersistence.shared.set(.liquidGlass, value: isLiquidGlassEnabled) }
    }
    
    // ── Status Messages ──
    @Published var statusMessage: String?
    @Published var statusIcon: String?
    
    // ── Gesture Feedback ──
    @Published var lastGesture: FaceGesture = .none
    @Published var showGestureFeedback = false
    
    // ── Glance HUD ──
    @Published var glanceNotification: GlanceNotification? = nil
    

    
    // ── Private ──
    private var gestureFeedbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // ── Structs ──
    struct GlanceNotification: Identifiable {
        let id = UUID()
        let appName: String
        let title: String
        let icon: NSImage?
    }
    
    // ════════════════════════════════════════
    // MARK: - Init
    // ════════════════════════════════════════
    
    init() {
        // Observer for closing all panels (e.g. from Launcher)
        NotificationCenter.default.addObserver(forName: Notification.Name("closePanel"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.closeAllPanels() }
        }
        wireControllers()
        startNotificationMonitor()
        startClipboardMonitor()
        setupGestureNotifications()
        startGestureMonitor()
        
        // Start interceptor for volume/brightness keys
        MediaKeyInterceptor.shared.start()
    }
    
    /// Wire child controller callbacks to this orchestrator
    private func wireControllers() {
        // Timer status messages
        timerManager.onStatusMessage = { [weak self] message, icon in
            self?.showStatus(message, icon: icon)
        }
        
        // Focus status messages
        focus.onStatusMessage = { [weak self] message, icon in
            self?.showStatus(message, icon: icon)
        }
        
        // 🧠 CORTEX ghost toast — notify when new ghosts appear
        cortex.onNewGhosts = { [weak self] newCount in
            self?.showStatus("🧠 +\(newCount) ghost\(newCount > 1 ? "s" : "")", icon: "eye.fill", duration: 3.0)
        }
        
        // Forward music objectWillChange to trigger view updates
        music.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        battery.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        timerManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        focus.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        ai.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        swarm.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        tipEngine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        bioLum.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        userMode.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        scriptDrop.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        cortex.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Wire TipEngine callback
        tipEngine.onTipReady = { [weak self] tip in
            self?.showTip(tip)
        }
        
        // Feed swarm state into BioLumEngine
        swarm.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let liveAgents = self.swarm.agents.filter { $0.isAlive }
                let working = liveAgents.filter { $0.isWorking }
                let workload = liveAgents.isEmpty ? 0 : Double(working.count) / Double(liveAgents.count)
                self.bioLum.updateSwarmState(agentCount: liveAgents.count, workload: workload)
            }
            .store(in: &cancellables)
        
        // Feed battery state
        battery.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.bioLum.batteryLevel = Double(self.battery.batteryLevel) / 100.0
                self.bioLum.isCharging = self.battery.isCharging
            }
            .store(in: &cancellables)
        
        // Feed CORTEX ghost urgency into BioLum
        cortex.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.bioLum.cortexUrgency = self.cortex.ghostUrgency
                
                // Feed NervousSystem
                NervousSystem.shared.cortexGhostCount = self.cortex.ghostCount
                NervousSystem.shared.cortexConnected = (self.cortex.connectionState == .connected)
                
                // Auto-switch BioLum to cortexPulse when CORTEX panel is visible
                if self.isCortexVisible && self.bioLum.activeMode != .cortexPulse {
                    self.bioLum.activeMode = .cortexPulse
                }
            }
            .store(in: &cancellables)
    }
    
    // ════════════════════════════════════════
    // MARK: - Status Messages
    // ════════════════════════════════════════
    
    func showStatus(_ message: String, icon: String, duration: TimeInterval = 2.0) {
        withAnimation(DS.Anim.springNotify) {
            self.statusMessage = message
            self.statusIcon = icon
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.5)) {
                if self.statusMessage == message {
                    self.statusMessage = nil
                    self.statusIcon = nil
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Gesture Monitor
    // ════════════════════════════════════════
    
    func startGestureMonitor() {
        NervousSystem.shared.$lastDetectedGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gesture in
                if gesture != .none {
                    self?.triggerGestureFeedback(gesture)
                }
            }
            .store(in: &cancellables)
    }
    
    func triggerGestureFeedback(_ gesture: FaceGesture) {
        lastGesture = gesture
        showGestureFeedback = true
        HapticManager.shared.play(.success)
        
        gestureFeedbackTimer?.invalidate()
        gestureFeedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.5)) {
                    self?.showGestureFeedback = false
                }
            }
        }
    }
    
    // ── Gesture → AI Notifications ──
    private func setupGestureNotifications() {
        NotificationCenter.default.addObserver(forName: .gestureToggleAI, object: nil, queue: OperationQueue.main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                withAnimation(DS.Anim.springStd) {
                    self.ai.showAIBar.toggle()
                    if self.ai.showAIBar {
                        self.isExpanded = true
                    }
                }
                HapticManager.shared.play(.toggle)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .gestureClipboardAI, object: nil, queue: OperationQueue.main) { [weak self] notif in
            let text = notif.object as? String
            Task { @MainActor in
                guard let self = self, let text = text else { return }
                withAnimation(DS.Anim.springStd) {
                    self.isExpanded = true
                    self.ai.showAIBar = true
                }
                self.ai.processClipboard(text)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .gestureSummonBrain, object: nil, queue: OperationQueue.main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                withAnimation(DS.Anim.springStd) {
                    self.isExpanded = true
                    self.ai.showAIBar = true
                }
                HapticManager.shared.play(.heavy)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .gestureToggleNotch, object: nil, queue: OperationQueue.main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                withAnimation(DS.Anim.springNotify) {
                    self.isExpanded.toggle()
                }
                HapticManager.shared.play(.toggle)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Glance HUD
    // ════════════════════════════════════════
    
    func startNotificationMonitor() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: OperationQueue.main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                guard let self = self,
                      let app = app,
                      let name = app.localizedName,
                      let icon = app.icon else { return }
                if !self.isExpanded && !self.isMirrorActive {
                    self.showGlance(appName: name, title: "Active", icon: icon)
                }
            }
        }
    }
    
    func showGlance(appName: String, title: String, icon: NSImage?) {
        withAnimation(DS.Anim.springNotify) {
            glanceNotification = GlanceNotification(appName: appName, title: title, icon: icon)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.glanceNotification = nil
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - 💡 Tip HUD
    // ════════════════════════════════════════
    
    func showTip(_ tip: TipEngine.Tip) {
        // Don't show tips when expanded or during a glance
        guard !isExpanded && !isMirrorActive && !isClipboardVisible && !isBrainDumpVisible && !isSettingsVisible && !isSwarmVisible && glanceNotification == nil else { return }
        
        withAnimation(DS.Anim.springNotify) {
            tipNotification = tip
        }
        // Tips need longer reading time than glances
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) {
                if self?.tipNotification?.id == tip.id {
                    self?.tipNotification = nil
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Clipboard Monitor
    // ════════════════════════════════════════
    
    func startClipboardMonitor() {
        ClipboardMonitor.shared.onNewCopy = { [weak self] content, type in
            DispatchQueue.main.async {
                switch type {
                case .color:
                    self?.showStatus("Color: \(content)", icon: "paintpalette.fill")
                case .url:
                    self?.showStatus("🔗 Link Copied", icon: "link")
                case .code:
                    self?.showStatus("Code Snippet", icon: "chevron.left.forwardslash.chevron.right")
                case .text:
                    if content.count > 100 {
                        self?.showStatus("Text Copied (\(content.count)c)", icon: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Computed Properties
    // ════════════════════════════════════════
    
    var glowColor: Color {
        if music.isPlaying { return music.albumColor }
        if timerManager.timerActive { return .orange }
        if isDropTargetActive { return .cyan }
        return .clear
    }
    
    var hasGlow: Bool { music.isPlaying || timerManager.timerActive || isDropTargetActive }
    
    // ═══════════════════════════════════════════════════
    // MARK: - 🔄 Backward Compatibility Proxies
    // ═══════════════════════════════════════════════════
    // These proxy properties allow existing views to compile
    // without modification. Gradually migrate views to use
    // vm.music.properties, vm.battery.properties, etc. directly.
    
    var currentTrack: String { music.currentTrack }
    var currentArtist: String { music.currentArtist }
    var isPlaying: Bool { music.isPlaying }
    var albumColor: Color { music.albumColor }
    var albumColor2: Color { music.albumColor2 }
    var trackProgress: Double { music.trackProgress }
    var albumArtImage: NSImage? { music.albumArtImage }
    var trackDuration: Double { music.trackDuration }
    var trackPosition: Double { music.trackPosition }
    var volume: Float {
        get { music.volume }
        set { music.volume = newValue }
    }
    var showVolumeSlider: Bool {
        get { music.showVolumeSlider }
        set { music.showVolumeSlider = newValue }
    }
    var songChangeAlert: Bool { music.songChangeAlert }
    var trackTimeDisplay: String { music.trackTimeDisplay }
    var elapsedTimeString: String { music.elapsedTimeString }
    
    var batteryLevel: Int { battery.batteryLevel }
    var isCharging: Bool { battery.isCharging }
    var batteryIcon: String { battery.batteryIcon }
    
    var timerSeconds: Int { timerManager.timerSeconds }
    var timerActive: Bool { timerManager.timerActive }
    var timerDisplay: String { timerManager.timerDisplay }
    var timerProgress: Double { timerManager.timerProgress }
    var pomodoroMinutes: Int {
        get { timerManager.pomodoroMinutes }
        set { timerManager.pomodoroMinutes = newValue }
    }
    
    var focusScore: Double { focus.focusScore }
    var currentApp: String { focus.currentApp }
    var focusColor: Color { focus.focusColor }
    var isMinimalMode: Bool { focus.isMinimalMode }
    var activeContextApp: String? { focus.activeContextApp }
    
    var aiQuery: String {
        get { ai.aiQuery }
        set { 
            objectWillChange.send()
            ai.aiQuery = newValue 
        }
    }
    var aiResponse: String {
        get { ai.aiResponse }
        set { 
            objectWillChange.send()
            ai.aiResponse = newValue 
        }
    }
    var aiIsThinking: Bool { ai.aiIsThinking }
    var showAIBar: Bool {
        get { ai.showAIBar }
        set { 
            objectWillChange.send()
            ai.showAIBar = newValue 
        }
    }
    
    // Proxy methods
    func togglePlayPause() { music.togglePlayPause() }
    func nextTrack() { music.nextTrack() }
    func previousTrack() { music.previousTrack() }
    func seekTo(position: Double) { music.seekTo(position: position) }
    func openMusicApp() { music.openMusicApp() }
    func setVolume(_ value: Float) { music.setVolume(value) }
    func adjustVolume(by delta: Float) { music.adjustVolume(by: delta) }
    
    func startTimer(minutes: Int? = nil) { timerManager.start(minutes: minutes) }
    func stopTimer() { timerManager.stop() }
    
    func sendAIQuery() { ai.sendQuery() }
    
    // ── Missing Proxies ──
    func startNowPlayingMonitor() { music.startNowPlayingMonitor() }
    func updateBattery() { battery.update() }
    func updateVolume() { music.updateVolume() }
    

    
    // ── Zen Mode ──
    func toggleNotchVisibility() {
        withAnimation(DS.Anim.springNotify) {
            isNotchHidden.toggle()
        }
        if isNotchHidden {
            HapticManager.shared.play(.collapse) // Sound like "vanishing"
        } else {
            HapticManager.shared.play(.expand)   // Sound like "appearing"
        }
    }
    
    // ── Color Picker ──
    func activateColorPicker() {
        ColorPickerService.shared.pickColor { [weak self] color in
            guard let self = self, let color = color else { return }
            self.lastCapturedColor = color
            
            // Trigger feedback UI
            withAnimation(DS.Anim.springNotify) {
                self.showColorFeedback = true
                self.isExpanded = true // Briefly expand to show result if needed, or just show toast
            }
            
            // Auto-dismiss feedback after 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.showColorFeedback = false
                    // Optional: collapse if it was only opened for this?
                    // self.isExpanded = false 
                }
            }
        }
    }
    

    // MARK: - Vanguard Mode
    
    func toggleVanguard() {
        withAnimation(DS.Anim.springNotify) {
            isChronosActive = false
            isVanguardActive.toggle()
        }
    }
    
    func toggleChronos() {
        withAnimation(DS.Anim.springNotify) {
            isVanguardActive = false
            isChronosActive.toggle()
        }
    }
    
    func closeAllPanels() {
        isClipboardVisible = false
        isBrainDumpVisible = false
        isVolumeMixerVisible = false
        isSettingsVisible = false
        isAppLauncherVisible = false
        isMirrorActive = false
        isScriptDropVisible = false
        isClawBotVisible = false
        isEcosystemHubVisible = false
        isCortexVisible = false
        // Reset mode if needed?
        // mode = .expanded 
    }
}
