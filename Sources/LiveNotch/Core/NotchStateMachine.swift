import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - ⚙️ Notch State Machine — Enhanced with OnyxDispatcher
// Merged: LiveNotch states + OnyxNotch sendling/delivery + Ghost Hopper
// ═══════════════════════════════════════════════════

@MainActor
final class NotchStateMachine: ObservableObject {
    static let shared = NotchStateMachine()
    
    enum State: Equatable {
        case idle
        case audioWake    // Micro-indicator (2-6 bars), no expansion
        case peek         // 10-25% height, track + play/pause
        case expanded     // Full panel with all controls
        case sending      // OnyxDispatcher: File/data transfer in progress
        case delivery     // OnyxDispatcher: Success confirmation
    }
    
    @Published var state: State = .idle
    @Published var previousState: State = .idle
    @Published var isHoverExpandEnabled: Bool = true  // Kill switch
    @Published var hoverDelay: TimeInterval = 0.3     // Anti-accidental
    @Published var peekHeight: CGFloat = 0.15         // 15% height increase
    
    // ── OnyxDispatcher: File & Ghost Hopper ──
    @Published var droppedFiles: [URL] = []
    @Published var ghostFiles: [URL] = []  // Ghost Hopper — clipboard files

    @Published var aiResponse: String = ""
    
    private var hoverTimer: Timer?
    private var isHovering = false

    
    private init() {}
    
    // ── Glow Color (adapts to dropped file type) ──
    var glowColor: Color {
        if let firstFile = droppedFiles.first {
            return FileTypeColors.color(for: firstFile)
        }
        switch state {
        case .sending:  return DS.Colors.cyan
        case .delivery: return DS.Colors.signalGreen
        case .audioWake, .peek: return DS.Colors.accentBlue
        default:        return DS.Colors.textMuted
        }
    }
    
    var glowIntensity: Double {
        switch state {
        case .sending:   return 1.0
        case .delivery:  return 0.9
        case .expanded:  return 0.7
        case .peek:      return 0.5
        case .audioWake: return 0.3
        case .idle:      return 0.1
        }
    }
    
    func onHoverStart() {
        guard isHoverExpandEnabled else { return }
        isHovering = true
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isHovering else { return }
                if self.state == .idle || self.state == .audioWake {
                    self.transition(to: .peek)
                    HapticManager.shared.play(.peek)
                }
            }
        }
    }
    
    func onHoverEnd() {
        isHovering = false
        hoverTimer?.invalidate()
        if state == .peek {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self, !self.isHovering else { return }
                guard self.state == .peek else { return }  // Don't collapse if already expanded
                self.transition(to: self.shouldShowAudioWake ? .audioWake : .idle)
            }
        }
    }
    
    func onTap() {
        switch state {
        case .idle, .audioWake, .peek:
            transition(to: .expanded); HapticManager.shared.play(.expand)
        case .expanded:
            transition(to: shouldShowAudioWake ? .audioWake : .idle); HapticManager.shared.play(.collapse)
        case .sending, .delivery:
            break // Don't interrupt transfer states
        }
    }
    
    func onAudioStart() { if state == .idle { transition(to: .audioWake) } }
    func onAudioStop() { if state == .audioWake { transition(to: .idle) } }
    func toggleExpanded() { state == .expanded ? onTap() : onTap() }
    
    // ── OnyxDispatcher: File operations ──
    func onFileDrop(_ urls: [URL]) {
        droppedFiles = urls
        transition(to: .sending)
        HapticManager.shared.play(.expand)
        
        // Auto-complete after simulated transfer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard self?.state == .sending else { return }
            self?.transition(to: .delivery)
            HapticManager.shared.play(.expand)
            
            // Return to idle after delivery confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard self?.state == .delivery else { return }
                self?.droppedFiles = []
                self?.transition(to: .idle)
            }
        }
    }
    
    /// Ghost Hopper — Copy files to invisible clipboard
    func ghostCopy(_ urls: [URL]) {
        ghostFiles = urls
    }
    
    /// Ghost Hopper — Paste files from invisible clipboard
    func ghostPaste() -> [URL] {
        let files = ghostFiles
        ghostFiles = []
        return files
    }
    
    private var shouldShowAudioWake: Bool { AudioPulseEngine.shared.level > 0.01 }
    
    private func transition(to newState: State) {
        guard newState != state else { return }
        previousState = state
        withAnimation(DS.Anim.springStd) { state = newState }
    }
    
    var isExpanded: Bool { state == .expanded }
    var isPeeking: Bool { state == .peek }
    var isAudioWake: Bool { state == .audioWake }
    var isSending: Bool { state == .sending }
    var isDelivery: Bool { state == .delivery }
    
    var heightMultiplier: CGFloat {
        switch state {
        case .idle, .audioWake: return 1.0
        case .peek: return 1.0 + peekHeight
        case .expanded: return 2.5  // Full panel expansion
        case .sending: return 1.3   // Slightly expanded during transfer
        case .delivery: return 1.2  // Flash then collapse
        }
    }
}

