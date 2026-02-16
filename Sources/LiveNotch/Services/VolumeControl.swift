import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🔊 Volume Control
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — system volume via AppleScript

final class VolumeControl {
    static func getVolume() -> Float {
        let script = "output volume of (get volume settings)"
        guard let as_ = NSAppleScript(source: script) else { return 50 }
        var err: NSDictionary?
        let result = as_.executeAndReturnError(&err)
        return Float(result.int32Value)
    }
    
    static func setVolume(_ value: Float) {
        let vol = Int(max(0, min(100, value)))
        let script = "set volume output volume \(vol)"
        DispatchQueue.global(qos: .userInitiated).async {
            guard let as_ = NSAppleScript(source: script) else { return }
            var err: NSDictionary?
            as_.executeAndReturnError(&err)
        }
    }
}
