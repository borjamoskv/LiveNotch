import Foundation
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🌍 Browser Audio Monitor
// ═══════════════════════════════════════════════════
// Checks if browsers are playing audio (Youtube, etc.)
// Helper for MusicController's Exclusive Audio Mode.

final class BrowserAudioMonitor {
    static let shared = BrowserAudioMonitor()
    
    // Checks if any browser is currently outputting audio / playing media
    // Returns: (isPlaying: Bool, sourceName: String)
    func checkBrowserAudio() async -> (Bool, String) {
        return await withCheckedContinuation { continuation in
            let script = """
            -- Chrome / Brave / Arc / Edge (Chromium based)
            -- Check for 'audible' tab property if available, or title heuristics
            
            -- Safari
            -- Check for 'muted' property false and 'playing' true? (Harder in standard AS)
            
            -- Simplified Heuristic: Check window titles for common media indicators if possible
            -- or just return 'false' for now until we have better hooks.
            
            -- Actually, best way without extensions is checking if the app is preventing sleep due to media?
            -- Or checking CoreAudio output device clients? (Hard in Swift sandbox)
            
            -- Let's try a Chrome specific check for now:
            set browserPlaying to false
            set activeBrowser to ""
            
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            -- Chrome doesn't expose 'audible' to AS easily in all versions, 
                            -- but we can check title for "▶" or similar if we want (unreliable).
                            -- BETTER: execute JS.
                            -- "document.querySelectorAll('video, audio').length > 0 && !document.querySelectorAll('video, audio')[0].paused"
                            -- This is too invasive/slow for polling.
                        end repeat
                    end repeat
                end tell
            end if
            
            return "FALSE" 
            """
            
            // For now, return false as true browser monitoring requires invasive permissions
            // or CoreAudio TAP which we are avoiding for simplicity/security.
            // We will rely on the user manually pausing music for YouTube for now,
            // OR we can add a simple "Pause Music" button in the notch.
            
            continuation.resume(returning: (false, ""))
        }
    }
}
