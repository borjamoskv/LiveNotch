import SwiftUI
import AppKit
import ApplicationServices

// ═══════════════════════════════════════════════════
// MARK: - 👁️ Accessibility & Window Logic
// ═══════════════════════════════════════════════════

extension NervousSystem {
    
    // ════════════════════════════════════════
    // MARK: - Window Title Extraction
    // ════════════════════════════════════════
    
    func extractWindowTitle(pid: pid_t) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let appElement = AXUIElementCreateApplication(pid)
            var windowValue: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
            
            guard result == .success, let window = windowValue else {
                DispatchQueue.main.async {
                    self?.activeAppDetail = ""
                }
                return
            }
            
            var titleValue: AnyObject?
            // Fixed: Force cast replaced with safe binding
            // Fixed: Force cast as conditional downcast always succeeds for CFType
            let windowElement = window as! AXUIElement
            AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue)
            
            let title = (titleValue as? String) ?? ""
            
            // Clean up common title patterns
            let cleanTitle = self?.cleanWindowTitle(title) ?? title
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.activeAppDetail = cleanTitle
                }
            }
        }
    }
    
    /// Clean window titles for display in the small wing space
    func cleanWindowTitle(_ title: String) -> String {
        var clean = title
        
        // VS Code: "filename.swift — project-name — Visual Studio Code" → "filename.swift"
        if clean.contains(" — ") {
            clean = String(clean.split(separator: " — ").first ?? Substring(clean))
        }
        
        // Chrome/Safari: "Page Title - Google Chrome" → "Page Title"
        let browserSuffixes = [" - Google Chrome", " - Safari", " — Mozilla Firefox", " - Arc"]
        for suffix in browserSuffixes {
            if clean.hasSuffix(suffix) {
                clean = String(clean.dropLast(suffix.count))
            }
        }
        
        // Truncate if too long (wing space is tiny)
        if clean.count > 25 {
            clean = String(clean.prefix(22)) + "…"
        }
        
        return clean
    }
    
    // ════════════════════════════════════════
    // MARK: - Color Extraction from App Icon
    // ════════════════════════════════════════
    
    func extractDominantColor(from icon: NSImage?) -> Color? {
        guard let icon = icon,
              let tiffData = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        // Sample center pixels for dominant color
        let size = bitmap.size
        let cx = Int(size.width / 2)
        let cy = Int(size.height / 2)
        
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var count: CGFloat = 0
        
        // Sample a 5x5 grid from center
        for dx in -2...2 {
            for dy in -2...2 {
                let px = min(max(cx + dx * 3, 0), Int(size.width) - 1)
                let py = min(max(cy + dy * 3, 0), Int(size.height) - 1)
                if let color = bitmap.colorAt(x: px, y: py) {
                    totalR += color.redComponent
                    totalG += color.greenComponent
                    totalB += color.blueComponent
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return nil }
        
        let r = totalR / count
        let g = totalG / count
        let b = totalB / count
        
        // Skip if too dark or too desaturated
        let brightness = (r + g + b) / 3
        if brightness < 0.1 { return Color.white.opacity(0.3) }
        
        return Color(red: r, green: g, blue: b)
    }
    
    /// Fallback profile — extracts accent color from app icon
    func fallbackProfile(for app: NSRunningApplication) -> ChameleonProfile {
        return ChameleonProfile(
            accentColor: extractDominantColor(from: app.icon) ?? .white.opacity(0.3),
            icon: "bolt.fill",
            actionLabel: "Open",
            action: .expandPanel,
            breathMod: 1.0
        )
    }
}
