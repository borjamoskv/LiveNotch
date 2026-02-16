import SwiftUI
import Combine
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Nervous System — The Soul of the Notch
// ═══════════════════════════════════════════════════
//
// The notch is a living organism. It breathes, shifts color,
// and responds to context without demanding attention.
// This engine determines the emotional state of the notch.
//
// 🦎 App Chameleon: The notch becomes the app. Color, icon,
// and action adapt to whatever you're using right now.

final class NervousSystem: ObservableObject {
    static let shared = NervousSystem()
    
    // ── Mood States ──
    enum Mood: String, CaseIterable {
        case idle       // ⚪ Nothing happening — barely visible
        case focus      // 🟢 Deep work — same app >3min, low distractions
        case active     // 🔵 Normal work — switching apps, moderate activity
        case stressed   // 🔴 System under load — high CPU, many switches
        case music      // 🎵 Music playing — album color dominates
        case meeting    // 🟡 Video call active — Zoom/Meet/Teams/FaceTime
    }
    
    // ── Smart Actions ──
    // SmartAction enum moved to AppProfiles.swift
    
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
    
    // ── AI Context Personas ──
    private let appContexts: [String: String] = [
        // Coding
        "com.microsoft.VSCode": "You are an expert software engineer. Focus on clean, performant code.",
        "com.todesktop.230510fqmkbjh6g": "You are an expert software engineer (Cursor). Suggest modern refactors.",
        "com.cursor.Cursor": "You are an expert software engineer (Cursor). Suggest modern refactors.",
        "com.apple.dt.Xcode": "You are an iOS/macOS expert. Focus on SwiftUI, Combine, and system frameworks.",
        "com.google.antigravity": "You are Antigravity, an advanced AI coding assistant. Modify the codebase directly.",
        
        // Creative
        "com.hnc.Discord": "You are a creative muse. Help generate Midjourney prompts and Suno lyrics.",
        "com.adobe.Photoshop": "You are a digital artist. Suggest composition, color theory, and techniques.",
        "com.ableton.live": "You are a music producer. Suggest chord progressions and sound design.",
        "com.image-line.flstudio": "You are a beatmaker. Suggest drum patterns and mixing tips.",
        
        // Research/Writing
        "com.apple.Safari": "You are a researcher. Summarize content and fact-check information.",
        "com.google.Chrome": "You are a researcher. Summarize content and fact-check information.",
        "ai.perplexity.mac": "You are a deep researcher. Cross-reference sources and find specific data.",
        "com.apple.iWork.Pages": "You are a professional editor. Improve grammar, tone, and clarity.",
        "md.obsidian": "You are a knowledge manager. Help organize thoughts and find connections.",
        "notion.id": "You are a productivity expert. Help structure project plans and databases."
    ]
    
    var currentAIContext: String {
        return appContexts[activeAppBundleID] ?? "You are Naroa, a sophisticated AI agent integrated into the macOS notch. You are helpful, concise, and aware of the user's system context."
    }

    // ── Tracking ──
    // masterHeartbeat removed — now managed by SmartPolling coordinator
    private var tick: UInt64 = 0
    
    private var meetingStartDate: Date?
    private var appSwitchTimestamps: [Date] = []
    private var lastMoodChange = Date()
    private var lastInputTime = Date()
    private var flowStartTime: Date?
    private var sessionStartTime = Date()
    private var cancellables = Set<AnyCancellable>()
    private var lastActiveBundle: String = ""
    
    // Meeting apps
    private let meetingBundleIDs = [
        "us.zoom.xos",
        "com.apple.FaceTime",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.tinyspeck.slackmacgap",
        "com.cisco.webexmeetingsapp"
    ]
    
    private init() {
        NSLog("🧠 NervousSystem: init START")
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
        
        NSLog("🧠 NervousSystem: calling setupGestureEye...")
        setupGestureEye()
        
        // 🔮 Sync with Notch Intelligence (Thinking State)
        NotchIntelligence.shared.$isThinking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thinking in
                self?.isThinkingAI = thinking
                self?.evaluateMood()
            }
            .store(in: &cancellables)
            
        NSLog("🧠 NervousSystem: init COMPLETE")
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
    // MARK: - Mood Engine
    // ════════════════════════════════════════
    // Mood is evaluated every 2s via checkMood() called by pulse()
    
    private func evaluateMood() {
        let cpu = SystemMonitor.shared.cpuUsage
        let isPlaying = isPlayingMusic
        let switchRate = recentAppSwitchRate()
        
        let newMood: Mood
        
        // Priority-based mood selection
        if isMeetingActive {
            newMood = .meeting
        } else if isPlaying {
            newMood = .music
        } else if cpu > 70 || switchRate > 8 {
            newMood = .stressed
        } else if isAsleep {
            newMood = .idle
        } else if isInFlowState {
            newMood = .focus
        } else if switchRate < 2 && cpu < 30 {
            let hasRecentInput = switchRate > 0
            newMood = hasRecentInput ? .focus : .idle
        } else if isThinkingAI {
            newMood = .active // We'll boost intensity in active or create a sub-state
        } else {
            newMood = .active
        }
        
        // Only transition if mood actually changed (with debounce)
        if newMood != currentMood {
            let timeSinceLastChange = Date().timeIntervalSince(lastMoodChange)
            if timeSinceLastChange > 3.0 || newMood == .music || newMood == .meeting {
                transitionTo(newMood)
            }
        }
    }
    
    private func transitionTo(_ mood: Mood) {
        lastMoodChange = Date()
        
        withAnimation(.easeInOut(duration: 1.5)) {
            currentMood = mood
            
            // 🪞 Emotional modulation: anxiety speeds breathing, calm slows it
            let anxietyMod = 1.0 - (anxietyLevel * 0.4)  // high anxiety → faster
            let energyMod = 0.7 + (energyCurve * 0.6)     // low energy → slower
            
            switch mood {
            case .idle:
                if isAsleep {
                    // 😴 Sleep mode: nearly invisible
                    moodColor = .white.opacity(0.02)
                    breathRate = 10.0  // very slow, barely perceptible
                    breathIntensity = 0.015
                } else {
                    moodColor = .white.opacity(0.05)
                    breathRate = 6.0 * anxietyMod * energyMod
                    breathIntensity = 0.03
                }
                smartAction = .expandPanel
                smartIcon = "bolt.fill"
                
            case .focus:
                // 🦎 In focus mode, use the app's color
                moodColor = activeAppColor.opacity(isInFlowState ? 0.7 : 0.5)
                breathRate = isInFlowState ? 5.0 : 4.0 * anxietyMod  // flow = deep calm
                breathIntensity = isInFlowState ? 0.04 : 0.06
                applyChameleonOverrides()
                
            case .active:
                // 🦎 Active: tinted by current app, modulated by anxiety
                moodColor = activeAppColor.opacity(0.5)
                breathRate = max(1.5, 2.5 * anxietyMod * energyMod)
                breathIntensity = 0.06 + (anxietyLevel * 0.04)  // more anxious = more visible
                applyChameleonOverrides()
                
            case .stressed:
                moodColor = Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.5)
                breathRate = 0.8
                breathIntensity = 0.12
                smartAction = .expandPanel
                smartIcon = "bolt.fill"
                
            case .music:
                breathRate = 2.0 * energyMod
                breathIntensity = 0.10
                smartAction = .nextTrack
                smartIcon = "forward.fill"
                
            case .meeting:
                moodColor = Color(red: 0.9, green: 0.7, blue: 0.1).opacity(0.6)
                breathRate = 0
                breathIntensity = 0.15
                smartAction = .showMeeting
                smartIcon = "video.fill"
            }
            
            // ── AI Thinking Override (Top Priority for Visuals) ──
            if isThinkingAI {
                breathRate = 0.8
                breathIntensity = 0.15
                moodColor = Color.cyan.opacity(0.6) // Psionic blue
            }
            
            // 🌅 Time-of-day color temperature overlay
            applyTimeOfDayTint()
        }
    }
    
    /// 🦎 Apply chameleon overrides from the active app profile
    private func applyChameleonOverrides() {
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
    
    // ════════════════════════════════════════
    // MARK: - 🪞 Emotional Mirror Engine
    // ════════════════════════════════════════
    //
    // This is the SOUL. The notch reflects YOUR state:
    // - Anxiety from app-switching frequency
    // - Energy from time of day
    // - Flow from sustained focus
    // - Sleep from inactivity
    
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
        
        // Emotional Mirror: Global input tracking is now handled in init()
        // Emotional evaluation is handled by pulse()
    }
    
    private func evaluateEmotionalState() {
        let now = Date()
        
        // ── 1. Anxiety: app switches in last 60s ──
        let switchRate = recentAppSwitchRate()
        let targetAnxiety = min(Double(switchRate) / 10.0, 1.0)  // 10+ switches/min = max anxiety
        
        withAnimation(.easeInOut(duration: 3.0)) {
            // Smooth towards target (don't snap)
            anxietyLevel = anxietyLevel * 0.7 + targetAnxiety * 0.3
        }
        
        // ── 2. Energy: circadian curve ──
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let hourDecimal = Double(hour) + Double(minute) / 60.0
        
        // Energy peaks at 10am and 3pm, dips at 2pm (post-lunch) and after 10pm
        let targetEnergy: Double
        switch hourDecimal {
        case 6..<9:    targetEnergy = 0.4 + (hourDecimal - 6) * 0.15   // Morning ramp up
        case 9..<12:   targetEnergy = 0.85 + sin((hourDecimal - 9) * .pi / 3) * 0.15  // Morning peak
        case 12..<14:  targetEnergy = 0.7 - (hourDecimal - 12) * 0.1  // Post-lunch dip
        case 14..<17:  targetEnergy = 0.5 + sin((hourDecimal - 14) * .pi / 3) * 0.3  // Afternoon peak
        case 17..<21:  targetEnergy = 0.6 - (hourDecimal - 17) * 0.08 // Evening decline
        case 21..<24:  targetEnergy = max(0.15, 0.3 - (hourDecimal - 21) * 0.05)  // Night wind down
        default:       targetEnergy = 0.15  // Late night / early morning
        }
        
        withAnimation(.easeInOut(duration: 5.0)) {
            energyCurve = energyCurve * 0.8 + targetEnergy * 0.2
        }
        
        // ── 3. Flow state: same app for >5 min + low switch rate ──
        let timeSinceLastSwitch: TimeInterval
        if let lastSwitch = appSwitchTimestamps.last {
            timeSinceLastSwitch = now.timeIntervalSince(lastSwitch)
        } else {
            timeSinceLastSwitch = now.timeIntervalSince(sessionStartTime)
        }
        
        let wasInFlow = isInFlowState
        if timeSinceLastSwitch > 300 && switchRate <= 1 {  // 5+ min same app, ≤1 switch
            if !isInFlowState {
                flowStartTime = now
                withAnimation(.easeInOut(duration: 3.0)) {
                    isInFlowState = true
                }
            }
        } else {
            if isInFlowState {
                flowStartTime = nil
                withAnimation(.easeInOut(duration: 2.0)) {
                    isInFlowState = false
                }
            }
        }
        
        // ── 4. Sleep detection: no input for >5 min ──
        let timeSinceInput = now.timeIntervalSince(lastInputTime)
        if timeSinceInput > 300 && !isAsleep {  // 5 min
            withAnimation(.easeInOut(duration: 4.0)) {
                isAsleep = true
            }
        }
        
        // ── 5. Session duration ──
        sessionMinutes = Int(now.timeIntervalSince(sessionStartTime) / 60)
        
        // ── 6. Compute final ambient glow ──
        computeAmbientGlow()
        
        // Re-evaluate mood with new emotional data
        if !wasInFlow && isInFlowState || wasInFlow && !isInFlowState {
            evaluateMood()
        }
    }
    
    /// Compute the final ambient glow color based on all emotional inputs
    private func computeAmbientGlow() {
        withAnimation(.easeInOut(duration: 2.0)) {
            if isAsleep {
                ambientGlow = .white.opacity(0.02)
            } else if isPlayingMusic {
                ambientGlow = moodColor  // Music dominates
            } else if isInFlowState {
                // Flow: deep, calm version of app color
                ambientGlow = activeAppColor.opacity(0.4)
            } else {
                // Normal: blend app color with anxiety intensity
                let intensity = 0.2 + anxietyLevel * 0.3
                ambientGlow = activeAppColor.opacity(intensity)
            }
        }
    }
    
    /// 🌅 Shift color temperature based on time of day
    private func applyTimeOfDayTint() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Late night (11pm-5am): dim everything significantly
        if hour >= 23 || hour < 5 {
            breathIntensity *= 0.5
            // Don't override moodColor — just reduce intensity
        }
        // Morning (6-8am): warm golden bias
        else if hour >= 6 && hour < 8 {
            // Subtle warm tint — don't override, just nudge
            if currentMood == .idle || currentMood == .active {
                moodColor = Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.15)
            }
        }
        // Evening (8-10pm): warm amber
        else if hour >= 20 && hour < 23 {
            breathIntensity *= 0.8
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Meeting Detection
    // ════════════════════════════════════════
    
    private func startMeetingDetection() {
        // Meeting detection is handled by pulse()
    }
    
    private func checkForMeetings() {
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
    
    // Window title extraction moved to NervousSystem+Accessibility.swift
    
    // Color extraction moved to NervousSystem+Accessibility.swift
    
    /// Switches per minute in the last 60 seconds
    private func recentAppSwitchRate() -> Int {
        let cutoff = Date().addingTimeInterval(-60)
        return appSwitchTimestamps.filter { $0 > cutoff }.count
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
    
    // Gesture handling moved to NervousSystem+Gestures.swift
    
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
