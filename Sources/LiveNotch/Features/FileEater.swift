import Cocoa
import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 👾 File Eater — The Notch Devours Files
// ═══════════════════════════════════════════════════
//
// Drop any file onto the Notch. It "eats" it with a vortex animation.
// Drag from the Notch to "spit" it back out anywhere.
//
// Zero new permissions needed. Uses standard NSPasteboard.
// The Notch becomes a clipboard for files.
//
// States:
//   🟢 Empty    → transparent, ready
//   🔵 Hovering → magnetic pull, border glows cyan
//   🔴 Eating   → vortex suck animation + flash
//   🟡 Full     → breathing pulse glow, shows count
//   ⚪ Spitting → reverse vortex as you drag out
//

@MainActor
final class FileEater: ObservableObject {
    static let shared = FileEater()
    private let log = NotchLog.make("FileEater")
    
    
    // ── State ──
    @Published var storedFiles: [URL] = []
    @Published var isHovering: Bool = false
    @Published var isEating: Bool = false
    @Published var lastEatenFileName: String? = nil
    
    var fileCount: Int { storedFiles.count }
    var isFull: Bool { !storedFiles.isEmpty }
    var capacity: Int { 20 } // Max files before "indigestion"
    
    // ── Feed the beast ──
    func eat(_ urls: [URL]) {
        let remaining = capacity - storedFiles.count
        let toEat = Array(urls.prefix(remaining))
        
        guard !toEat.isEmpty else {
            // Notch is full — "indigestion" haptic
            HapticManager.shared.play(.error)
            return
        }
        
        isEating = true
        
        for url in toEat {
            // Bookmark for security-scoped access later
            if let bookmark = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                let bookmarkURL = restoreBookmark(bookmark) ?? url
                storedFiles.append(bookmarkURL)
            } else {
                storedFiles.append(url)
            }
        }
        
        lastEatenFileName = toEat.last?.lastPathComponent
        HapticManager.shared.play(.drop)
        
        log.info("Ate \(toEat.count) files (total: \(storedFiles.count))")
        
        // End eating animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isEating = false
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .fileEaterDidEat, object: toEat.count)
    }
    
    // ── Spit one out ──
    func spit() -> [URL]? {
        guard !storedFiles.isEmpty else { return nil }
        let urls = storedFiles
        storedFiles.removeAll()
        HapticManager.shared.play(.subtle)
        log.info("Spat \(urls.count) files")
        return urls
    }
    
    // ── Spit specific file ──
    func spit(at index: Int) -> URL? {
        guard index < storedFiles.count else { return nil }
        let url = storedFiles.remove(at: index)
        HapticManager.shared.play(.subtle)
        return url
    }
    
    // ── Clear stomach ──
    func purge() {
        storedFiles.removeAll()
        lastEatenFileName = nil
        HapticManager.shared.play(.toggle)
        log.info("Purged all files")
    }
    
    // ── Bookmark restoration ──
    private func restoreBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        
        if isStale { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }
}

// ═══════════════════════════════════════════════════
// MARK: - File Eater Drop Zone (SwiftUI overlay)
// ═══════════════════════════════════════════════════

struct FileEaterDropZone: View {
    @ObservedObject var eater = FileEater.shared
    @State private var glowPhase: Double = 0
    @State private var vortexScale: Double = 1.0
    @State private var flashOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // ── Full indicator: breathing dot ──
            if eater.isFull && !eater.isHovering {
                Circle()
                    .fill(fileCountColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: fileCountColor.opacity(0.6), radius: 4)
                    .opacity(0.5 + 0.5 * sin(glowPhase))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            glowPhase = .pi
                        }
                    }
            }
            
            // ── Hover indicator: magnetic pull ──
            if eater.isHovering {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.cyan, .purple, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .opacity(0.5 + 0.5 * sin(glowPhase * 3))
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
                    .scaleEffect(1.02 + 0.01 * sin(glowPhase * 5))
            }
            
            // ── Eating: vortex + flash ──
            if eater.isEating {
                // Flash
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .opacity(flashOpacity)
                    .onAppear {
                        flashOpacity = 0.8
                        withAnimation(.easeOut(duration: 0.4)) {
                            flashOpacity = 0
                        }
                    }
                
                // Vortex spiral
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(vortexScale)
                    .rotationEffect(.degrees(glowPhase * 100))
                    .onAppear {
                        vortexScale = 1.2
                        withAnimation(.easeIn(duration: 0.5)) {
                            vortexScale = 0.0
                        }
                    }
            }
            
            // ── File count badge ──
            if eater.fileCount > 1 {
                Text("\(eater.fileCount)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(fileCountColor.opacity(0.8))
                    )
                    .offset(x: 20, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false) // Overlay only — the NSView handles interaction
    }
    
    private var fileCountColor: Color {
        switch eater.fileCount {
        case 0: return .clear
        case 1...3: return .cyan
        case 4...7: return .orange
        default: return .red
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - AppKit Drop Target (NSView for drag operations)
// ═══════════════════════════════════════════════════

class FileEaterNSView: NSView {
    private let eater = FileEater.shared
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }
    
    // ── Drag Enter ──
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DispatchQueue.main.async { [weak self] in
            self?.eater.isHovering = true
        }
        return .copy
    }
    
    // ── Drag Exit ──
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async { [weak self] in
            self?.eater.isHovering = false
        }
    }
    
    // ── Drop! ──
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.eater.isHovering = false
        }
        
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.eater.eat(items)
        }
        
        return true
    }
    
    // ── Drag Out (spit files back) ──
    override func mouseDown(with event: NSEvent) {
        guard eater.isFull else { return }
        guard let urls = eater.spit() else { return }
        
        let pasteboardItem = NSPasteboardItem()
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        
        let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        dragItem.setDraggingFrame(bounds, contents: NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil))
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

extension FileEaterNSView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Notification Names
// ═══════════════════════════════════════════════════

extension Notification.Name {
    static let fileEaterDidEat = Notification.Name("notch.fileEater.didEat")
    static let fileEaterDidSpit = Notification.Name("notch.fileEater.didSpit")
}
