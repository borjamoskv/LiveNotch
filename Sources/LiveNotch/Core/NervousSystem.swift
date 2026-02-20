import SwiftUI
import Combine
import AppKit
import os

private let nervousLog = NotchLog.make("NervousSystem")

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Nervous System — The Soul of the Notch
// ═══════════════════════════════════════════════════
// ═══════════════════════════════════════════════════

final class NervousSystem: ObservableObject {
    static let shared = NervousSystem()
    
    // ── Published State ──
    @Published var currentMood: Mood = .idle
    @Published var moodColor: Color = .white.opacity(0.1)
    @Published var breathRate: Double = 4.0   // seconds per breath cycle
    @Published var breathIntensity: Double = 0.05  // max glow opacity
    @Published var smartAction: SmartAction = .expandPanel
    @Published var smartIcon: String = "bolt.fill"
    @Published var isMeetingActive: Bool = false
    @Published var meetingDuration: TimeInterval = 0
    @Published var isThinkingAI: Bool = false
    @Published var cortexGhostCount: Int = 0
    @Published var cortexConnected: Bool = false
    
    // 🦎 App Chameleon State
    @Published var chameleonEnabled: Bool = NotchPersistence.shared.bool(.chameleonEnabled, default: true) {
        didSet { NotchPersistence.shared.set(.chameleonEnabled, value: chameleonEnabled) }
    }
    @Published var activeAppBundleID: String = ""
    @Published var activeAppName: String = ""
    @Published var activeAppIcon: NSImage? = nil
    @Published var activeAppColor: Color = .white.opacity(0.3)
    @Published var activeAppDetail: String = ""  // window title / doc name
    
    // 🪞 Emotional Mirror State
    @Published var anxietyLevel: Double = 0      // 0.0 (zen) → 1.0 (frantic multitask)
    @Published var energyCurve: Double = 0.5     // 0.0 (exhausted) → 1.0 (peak energy)
    @Published var isInFlowState: Bool = false   // >5 min same app, low switch rate
    @Published var isAsleep: Bool = false         // no input for >5 min
    @Published var ambientGlow: Color = .white.opacity(0.1)  // final computed glow
    @Published var sessionMinutes: Int = 0        // how long since last long break
    
    // 👁️ Eye Gesture Stream
    @Published var lastDetectedGesture: FaceGesture = .none
    

    // ── Tracking ──
    // masterHeartbeat removed — now managed by SmartPolling coordinator
    private var tick: UInt64 = 0
    
    var meetingStartDate: Date?
    var appSwitchTimestamps: [Date] = []
    var lastMoodChange = Date()
    var lastInputTime = Date()
    var flowStartTime: Date?
    var sessionStartTime = Date()
    private var cancellables = Set<AnyCancellable>()
    private var lastActiveBundle: String = ""
    
    private init() {
        #if DEBUG
        nervousLog.debug("🧠 NervousSystem: init START")
        #endif
        startHeartbeat()
        observeAppSwitches()
        
        // Emotional Mirror: Global input tracking
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel]) { [weak self] _ in
            self?.lastInputTime = Date()
            if self?.isAsleep == true {
                // Wake up animation
                withAnimation(.easeOut(duration: 2.0)) {
                    self?.isAsleep = false
                }
            }
        }
        
        #if DEBUG
        nervousLog.debug("🧠 NervousSystem: calling setupGestureEye...")
        #endif
        setupGestureEye()
        
        // 🔮 Sync with Notch Intelligence (Thinking State)
        NotchIntelligence.shared.$isThinking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thinking in
                self?.isThinkingAI = thinking
                self?.evaluateMood()
            }
            .store(in: &cancellables)
            
        #if DEBUG
        nervousLog.debug("🧠 NervousSystem: init COMPLETE")
        #endif
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - 🫀 The Heartbeat (Unified Timer)
    // ═══════════════════════════════════════════════
    
    private func startHeartbeat() {
        // Register with SmartPolling coordinator — adaptive rates
        SmartPolling.shared.register("nervous.pulse", interval: .adaptive(active: 1.0, idle: 3.0)) { [weak self] in
            self?.pulse()
        }
    }
    
    private func pulse() {
        tick += 1
        
        // 1. Every 2s: Mood Evaluation
        if tick % 2 == 0 {
            evaluateMood()
        }
        
        // 2. Every 5s: Deep Context Check (Meetings, Emotion, Flow)
        if tick % 5 == 0 {
            checkForMeetings()
            evaluateEmotionalState()
        }
    }
    
    // AppProfile struct and dictionary moved to AppProfiles.swift
    

    // ════════════════════════════════════════
    // MARK: - Chameleon Engine
    // ════════════════════════════════════════
    
    /// 🦎 Apply chameleon overrides from the active app profile
    internal func applyChameleonOverrides() {
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let profile = chameleonProfiles[bundleID] {
            smartAction = profile.action
            smartIcon = profile.icon
            if profile.breathMod != 1.0 && profile.breathMod > 0 {
                breathRate *= profile.breathMod
            } else if profile.breathMod == 0 {
                breathRate = 0
            }
        } else {
            smartAction = .expandPanel
            smartIcon = "bolt.fill"
        }
    }
    
    private func startEmotionalMirror() {
        // Track keyboard/mouse activity for idle/sleep detection
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel]) { [weak self] _ in
            self?.lastInputTime = Date()
            if self?.isAsleep == true {
                // Wake up animation
                withAnimation(.easeOut(duration: 2.0)) {
                    self?.isAsleep = false
                }
            }
        }
    }
    
    
    /// Compute the final ambient glow color based on all emotional inputs

    
    private func checkForMeetings() {
        let meetingBundleIDs = [
            "us.zoom.xos",
            "com.apple.FaceTime",
            "com.microsoft.teams",
            "com.microsoft.teams2",
            "com.tinyspeck.slackmacgap",
            "com.cisco.webexmeetingsapp"
        ]
        let running = NSWorkspace.shared.runningApplications
        let meetingFound = running.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return meetingBundleIDs.contains(bundleID) && !app.isHidden
        }
        
        if meetingFound && !isMeetingActive {
            isMeetingActive = true
            meetingStartDate = Date()
        } else if !meetingFound && isMeetingActive {
            isMeetingActive = false
            meetingStartDate = nil
            meetingDuration = 0
        }
        
        if let start = meetingStartDate {
            meetingDuration = Date().timeIntervalSince(start)
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - App Switch Tracking + Chameleon
    // ════════════════════════════════════════
    
    private func observeAppSwitches() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            self?.appSwitchTimestamps.append(Date())
            // Keep only last 60s of switches
            let cutoff = Date().addingTimeInterval(-60)
            self?.appSwitchTimestamps.removeAll { $0 < cutoff }
            
            // 🦎 Chameleon: update active app context
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.updateChameleon(for: app)
            }
        }
        
        // Initialize with current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            updateChameleon(for: frontmost)
        }
    }
    
    /// 🦎 Core chameleon update — called on every app switch
    private func updateChameleon(for app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier ?? ""
        guard bundleID != lastActiveBundle else { return }
        lastActiveBundle = bundleID
        
        let appName = app.localizedName ?? "Unknown"
        let icon = app.icon
        
        // Get profile (known or fallback)
        // Get profile (known or fallback)
        let prof = chameleonProfiles[bundleID] ?? fallbackProfile(for: app)
        
        withAnimation(.easeInOut(duration: 1.2)) {
            activeAppBundleID = bundleID
            activeAppName = appName
            activeAppIcon = icon
            activeAppColor = prof.accentColor
        }
        
        // Update smart action if not in music/meeting mode
        if currentMood != .music && currentMood != .meeting {
            withAnimation(.easeInOut(duration: 0.6)) {
                smartAction = prof.action
                smartIcon = prof.icon
                
                // Update mood color to app color (when not stressed)
                if currentMood != .stressed {
                    moodColor = prof.accentColor.opacity(currentMood == .focus ? 0.6 : 0.5)
                }
            }
        }
        
        // Extract window title via Accessibility (runs async)
        extractWindowTitle(pid: app.processIdentifier)
    }
    

    
    // ════════════════════════════════════════
    // MARK: - External State (set by ViewModel)
    // ════════════════════════════════════════
    
    /// Set by NotchViewModel when music playback state changes
    var isPlayingMusic = false {
        didSet {
            if isPlayingMusic != oldValue {
                handleMusicStateChange(isPlaying: isPlayingMusic)
            }
        }
    }
    
    // 👁️ GestureEye state (published for UI)
    @Published var gestureEyeActive: Bool = false
    @Published var gestureEyeFaceDetected: Bool = false
    @Published var gestureEyeLastGesture: FaceGesture = .none
    

    /// Format meeting duration as "12m" or "1h 23m"
    var meetingDurationFormatted: String {
        let mins = Int(meetingDuration) / 60
        let hours = mins / 60
        if hours > 0 {
            return "\(hours)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
    
    /// Check if we have a known profile for the active app
    var hasKnownProfile: Bool {
        return chameleonProfiles[lastActiveBundle] != nil
    }
}
