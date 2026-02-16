import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📋 Smart Clipboard Monitor
// ═══════════════════════════════════════════════════
// Real-time clipboard type detection for glance notifications

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    @Published var lastCopiedString: String = ""
    
    enum ClipboardType {
        case text, color, url, code
    }
    
    private var changeCount: Int
    // timer removed — now managed by SmartPolling coordinator
    var onNewCopy: ((String, ClipboardType) -> Void)?
    
    // Don't start immediately to avoid "on launch" trigger
    private init() {
        self.changeCount = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startMonitoring()
        }
    }
    
    func startMonitoring() {
        SmartPolling.shared.register("clipboard.check", interval: .adaptive(active: 0.8, idle: 2.0)) { [weak self] in
            self?.checkClipboard()
        }
    }
    
    private func isHexColor(_ str: String) -> Bool {
        let text = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("#") else { return false }
        guard text.count == 7 || text.count == 4 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef#")
        return text.rangeOfCharacter(from: allowed.inverted) == nil
    }
    
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != changeCount else { return }
        
        changeCount = currentCount
        
        if let str = NSPasteboard.general.string(forType: .string) {
            if str == lastCopiedString { return }
            lastCopiedString = str
            
            var type: ClipboardType = .text
            let lower = str.lowercased()
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isHexColor(trimmed) {
                type = .color
            } else if lower.hasPrefix("http") {
                type = .url
            } else if str.contains("func ") || str.contains("class ") || (str.contains("{") && str.contains("}")) {
                type = .code
            }
            
            DispatchQueue.main.async {
                self.onNewCopy?(str, type)
            }
        }
    }
}
