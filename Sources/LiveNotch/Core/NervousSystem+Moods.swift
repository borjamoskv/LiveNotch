import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎭 Mood Evaluation & Transitions
// ═══════════════════════════════════════════════════
//
// Extracted from NervousSystem.swift for organizational clarity.
// Contains: weighted mood scoring, per-mood breath curves,
// ambient glow computation, and time-of-day color tinting.

extension NervousSystem {
    
    // ════════════════════════════════════════
    // MARK: - Bundle ID Sets (Mood Detection)
    // ════════════════════════════════════════
    
    /// Meeting apps → `.meeting` mood
    static let meetingBundleIDs: Set<String> = [
        "us.zoom.xos",
        "com.apple.FaceTime",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.tinyspeck.slackmacgap",
        "com.cisco.webexmeetingsapp"
    ]
    
    /// Creative apps → `.creative` mood
    static let creativeBundleIDs: Set<String> = [
        "com.adobe.Photoshop", "com.adobe.Illustrator",
        "com.figma.Desktop", "com.seriflabs.affinitydesigner2",
        "com.procreate.canvases", "com.ableton.live",
        "com.image-line.flstudio", "com.apple.garageband",
        "com.apple.iMovie", "com.apple.FinalCut",
        "com.blackmagic-design.DaVinciResolve"
    ]
    
    /// Coding apps → `.coding` mood
    static let codingBundleIDs: Set<String> = [
        "com.microsoft.VSCode", "com.apple.dt.Xcode",
        "com.todesktop.230510fqmkbjh6g", "com.cursor.Cursor",
        "com.todesktop.230313mzl4w4u92",
        "com.googlecode.iterm2", "com.apple.Terminal",
        "dev.warp.Warp-Stable", "com.google.antigravity"
    ]
    
    // ════════════════════════════════════════
    // MARK: - Weighted Mood Scoring
    // ════════════════════════════════════════
    
    /// Evaluate current mood using weighted scoring.
    /// Each candidate gets a weight. Highest wins. Prevents flickering.
    func evaluateMood() {
        let cpu = SystemMonitor.shared.cpuUsage
        let isPlaying = isPlayingMusic
        let switchRate = recentAppSwitchRate()
        let bundle = activeAppBundleID
        let hour = Calendar.current.component(.hour, from: Date())
        
        var candidates: [(Mood, Int)] = []
        
        // Meeting: weight 100 (non-negotiable)
        if isMeetingActive {
            candidates.append((.meeting, 100))
        }
        
        // Music: weight 80
        if isPlaying {
            candidates.append((.music, 80))
        }
        
        // AI Thinking: weight 70
        if isThinkingAI {
            candidates.append((.active, 70))
        }
        
        // Creative app in focus: weight 60
        if Self.creativeBundleIDs.contains(bundle) && switchRate < 4 {
            candidates.append((.creative, 60))
        }
        
        // Coding app in focus: weight 50
        if Self.codingBundleIDs.contains(bundle) && switchRate < 4 {
            candidates.append((.coding, 50))
        }
        
        // System stress: weight 40
        if cpu > 70 || switchRate > 8 {
            candidates.append((.stressed, 40))
        }
        
        // Flow state: weight 35
        if isInFlowState {
            candidates.append((.focus, 35))
        }
        
        // Dreaming: late night + low activity → weight 30
        if (hour >= 23 || hour < 5) && switchRate < 2 && !isPlaying && !isMeetingActive {
            candidates.append((.dreaming, 30))
        }
        
        // Low activity focus: weight 20
        if switchRate < 2 && cpu < 30 && switchRate > 0 {
            candidates.append((.focus, 20))
        }
        
        // Sleep: weight 15
        if isAsleep {
            candidates.append((.idle, 15))
        }
        
        // Default fallback
        candidates.append((.active, 1))
        
        // 🧠 CORTEX ghost pressure: weight 45 (> stressed, <creative)
        if cortexGhostCount > 10 {
            candidates.append((.stressed, 45))
        } else if cortexGhostCount > 5 {
            // Moderate ghost pressure — increases anxiety but doesn't dominate
            candidates.append((.active, 25))
        }
        
        // Winner takes all
        let newMood = candidates.max(by: { $0.1 < $1.1 })?.0 ?? .active
        
        // Only transition if mood actually changed (with debounce)
        if newMood != currentMood {
            let timeSinceLastChange = Date().timeIntervalSince(lastMoodChange)
            let isImmediate = newMood == .music || newMood == .meeting
            if timeSinceLastChange > 3.0 || isImmediate {
                performTransition(to: newMood)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Per-Mood Breath Curves
    // ════════════════════════════════════════
    
    /// Transition to a new mood with per-mood visual configuration.
    func performTransition(to mood: Mood) {
        lastMoodChange = Date()
        
        withAnimation(.easeInOut(duration: 1.5)) {
            currentMood = mood
            
            // 🪞 Emotional modulation: anxiety speeds breathing, calm slows it
            let anxietyMod = 1.0 - (anxietyLevel * 0.4)  // high anxiety → faster
            let energyMod = 0.7 + (energyCurve * 0.6)     // low energy → slower
            
            switch mood {
            case .idle:
                if isAsleep {
                    moodColor = .white.opacity(0.02)
                    breathRate = 10.0
                    breathIntensity = 0.015
                } else {
                    moodColor = .white.opacity(0.05)
                    breathRate = 6.0 * anxietyMod * energyMod
                    breathIntensity = 0.03
                }
                smartAction = .expandPanel
                smartIcon = "bolt.fill"
                
            case .focus:
                moodColor = activeAppColor.opacity(isInFlowState ? 0.7 : 0.5)
                breathRate = isInFlowState ? 5.0 : 4.0 * anxietyMod
                breathIntensity = isInFlowState ? 0.04 : 0.06
                applyChameleonOverrides()
                
            case .active:
                moodColor = activeAppColor.opacity(0.5)
                breathRate = max(1.5, 2.5 * anxietyMod * energyMod)
                breathIntensity = 0.06 + (anxietyLevel * 0.04)
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
                
            case .creative:
                moodColor = Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.6)
                breathRate = max(1.2, 1.8 * anxietyMod)
                breathIntensity = 0.10 + (energyCurve * 0.05)
                applyChameleonOverrides()
                
            case .coding:
                moodColor = Color(red: 0.05, green: 0.3, blue: 0.7).opacity(0.5)
                breathRate = 3.0 * anxietyMod
                breathIntensity = 0.06
                applyChameleonOverrides()
                
            case .dreaming:
                moodColor = Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.2)
                breathRate = 8.0
                breathIntensity = 0.025
                smartAction = .expandPanel
                smartIcon = "moon.fill"
            }
            
            // AI Thinking Override (Top Priority for Visuals)
            if isThinkingAI {
                breathRate = 0.8
                breathIntensity = 0.15
                moodColor = Color.cyan.opacity(0.6)
            }
            
            applyTimeOfDayTintForMood()
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Ambient Glow
    // ════════════════════════════════════════
    
    /// Compute the final ambient glow color based on all emotional inputs.
    func computeAmbientGlow() {
        withAnimation(.easeInOut(duration: 2.0)) {
            switch currentMood {
            case .idle:
                ambientGlow = isAsleep ? .white.opacity(0.02) : .white.opacity(0.05)
            case .music:
                ambientGlow = moodColor
            case .creative:
                ambientGlow = Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.3 + energyCurve * 0.2)
            case .coding:
                ambientGlow = Color(red: 0.05, green: 0.3, blue: 0.7).opacity(0.25)
            case .dreaming:
                ambientGlow = Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.08)
            case .focus:
                ambientGlow = activeAppColor.opacity(isInFlowState ? 0.4 : 0.3)
            case .stressed:
                ambientGlow = Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.3)
            case .meeting:
                ambientGlow = Color(red: 0.9, green: 0.7, blue: 0.1).opacity(0.3)
            case .active:
                let intensity = 0.2 + anxietyLevel * 0.3
                ambientGlow = activeAppColor.opacity(intensity)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Time-of-Day Tint
    // ════════════════════════════════════════
    
    /// Shift color temperature based on time of day.
    func applyTimeOfDayTintForMood() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Late night (11pm-5am): dim everything significantly
        if hour >= 23 || hour < 5 {
            breathIntensity *= 0.5
        }
        // Morning (6-8am): warm golden bias
        else if hour >= 6 && hour < 8 {
            if currentMood == .idle || currentMood == .active {
                moodColor = Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.15)
            }
        }
        // Evening (8-10pm): warm amber
        else if hour >= 20 && hour < 23 {
            breathIntensity *= 0.8
        }
    }
}
