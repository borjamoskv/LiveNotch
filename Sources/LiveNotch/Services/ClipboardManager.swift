import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📋 Clipboard Manager
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — clipboard history

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    struct ClipItem: Identifiable, Equatable {
        let id = UUID()
        let content: String
        let timestamp: Date
        let isImage: Bool
        
        var preview: String {
            if isImage { return "📷 Image" }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 60 {
                return String(trimmed.prefix(57)) + "..."
            }
            return trimmed
        }
        
        var timeAgo: String {
            let seconds = Date().timeIntervalSince(timestamp)
            if seconds < 60 { return "now" }
            if seconds < 3600 { return "\(Int(seconds / 60))m" }
            return "\(Int(seconds / 3600))h"
        }
        
        static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    @Published var items: [ClipItem] = []
    private var lastChangeCount: Int = 0
    private let maxItems = 20
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        SmartPolling.shared.register("ClipboardManager", interval: .adaptive(active: 0.8, idle: 3.0)) { [weak self] in
            self?.checkClipboard()
        }
    }
    
    deinit {
        SmartPolling.shared.unregister("ClipboardManager")
    }
    
    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        
        // Check for image
        if pb.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.png.rawValue,
                                                       NSPasteboard.PasteboardType.tiff.rawValue]) {
            let item = ClipItem(content: "", timestamp: Date(), isImage: true)
            addItem(item)
            return
        }
        
        // Check for text
        if let text = pb.string(forType: .string), !text.isEmpty {
            if items.first?.content != text {
                let item = ClipItem(content: text, timestamp: Date(), isImage: false)
                addItem(item)
            }
        }
    }
    
    private func addItem(_ item: ClipItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.items.insert(item, at: 0)
            if self.items.count > self.maxItems {
                self.items = Array(self.items.prefix(self.maxItems))
            }
        }
    }
    
    func copyItem(_ item: ClipItem) {
        guard !item.isImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        HapticManager.shared.play(.success)
    }
    
    func clear() {
        items.removeAll()
    }
}
