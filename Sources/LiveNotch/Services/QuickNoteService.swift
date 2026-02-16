import SwiftUI
import Combine
import Foundation

// ═══════════════════════════════════════════════════════════
// MARK: - 📝 QuickNoteService — Instant Capture from Notch
// ═══════════════════════════════════════════════════════════
// Hover notch → 1-line input → auto-saved with timestamp.
// Auto-categorizes: tasks→Reminders, code→Dev, links→Readwise.
// Last 3 notes rotate in compact view.

@MainActor
final class QuickNoteService: ObservableObject {
    static let shared = QuickNoteService()
    private let log = NotchLog.make("QuickNoteService")
    
    // ─── State ───
    @Published var isCapturing = false
    @Published var captureText = ""
    @Published var recentNotes: [QuickNote] = []
    @Published var currentTemplate: NoteTemplate = .idea
    
    private let maxRecent = 20
    private let storageKey = "quicknotes"
    
    // ═══════════════════════════════════════════════════
    // MARK: - Types
    // ═══════════════════════════════════════════════════
    
    struct QuickNote: Identifiable, Codable, Equatable {
        let id: UUID
        let text: String
        let category: NoteCategory
        let timestamp: Date
        let appContext: String       // Active app when captured
        let template: NoteTemplate
        
        init(
            text: String,
            category: NoteCategory,
            appContext: String,
            template: NoteTemplate = .idea
        ) {
            self.id = UUID()
            self.text = text
            self.category = category
            self.timestamp = Date()
            self.appContext = appContext
            self.template = template
        }
        
        var timeAgo: String {
            let interval = Date().timeIntervalSince(timestamp)
            if interval < 60 { return "just now" }
            if interval < 3600 { return "\(Int(interval / 60))m ago" }
            if interval < 86400 { return "\(Int(interval / 3600))h ago" }
            return "\(Int(interval / 86400))d ago"
        }
        
        var icon: String {
            switch category {
            case .idea: return "💡"
            case .task: return "✅"
            case .code: return "💻"
            case .link: return "🔗"
            case .meeting: return "📋"
            case .reminder: return "⏰"
            }
        }
    }
    
    enum NoteCategory: String, Codable, CaseIterable {
        case idea = "Ideas"
        case task = "Tasks"
        case code = "Dev"
        case link = "Links"
        case meeting = "Meeting"
        case reminder = "Reminders"
    }
    
    enum NoteTemplate: String, Codable, CaseIterable {
        case idea = "Idea"
        case task = "Task"
        case code = "Code Snippet"
        case link = "Link"
        case meeting = "Meeting Notes"
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Initialization
    // ═══════════════════════════════════════════════════
    
    init() {
        loadNotes()
        log.info("QuickNoteService ready — \(recentNotes.count) notes loaded")
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Capture
    // ═══════════════════════════════════════════════════
    
    /// Begin capture mode (triggered by hover/gesture)
    func startCapture() {
        isCapturing = true
        captureText = ""
        detectTemplate()
    }
    
    /// Save the current capture
    func saveCapture() {
        guard !captureText.trimmingCharacters(in: .whitespaces).isEmpty else {
            isCapturing = false
            return
        }
        
        let category = categorize(captureText)
        let appContext = NervousSystem.shared.activeAppName
        
        let note = QuickNote(
            text: captureText,
            category: category,
            appContext: appContext,
            template: currentTemplate
        )
        
        recentNotes.insert(note, at: 0)
        if recentNotes.count > maxRecent {
            recentNotes = Array(recentNotes.prefix(maxRecent))
        }
        
        persistNotes()
        
        // Export to Apple Notes via AppleScript
        exportToAppleNotes(note)
        
        isCapturing = false
        captureText = ""
        log.info("Note saved: [\(category.rawValue)] \(note.text.prefix(40))...")
    }
    
    /// Cancel capture
    func cancelCapture() {
        isCapturing = false
        captureText = ""
    }
    
    /// Delete a note
    func deleteNote(_ note: QuickNote) {
        recentNotes.removeAll { $0.id == note.id }
        persistNotes()
    }
    
    /// Paste clipboard as note
    func pasteFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string) else { return }
        captureText = content
        startCapture()
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Auto-Categorization
    // ═══════════════════════════════════════════════════
    
    func categorize(_ text: String) -> NoteCategory {
        let lower = text.lowercased()
        
        // Task patterns
        let taskPatterns = ["llamar", "call", "comprar", "buy", "enviar", "send",
                            "hacer", "do", "todo", "fix", "deploy", "push"]
        if taskPatterns.contains(where: { lower.hasPrefix($0) || lower.contains("→ \($0)") }) {
            return .task
        }
        
        // Code patterns
        if lower.contains("func ") || lower.contains("let ") || lower.contains("var ") ||
           lower.contains("import ") || lower.contains("class ") || lower.contains("struct ") ||
           lower.contains("//") || lower.contains("{}") || lower.contains("()") {
            return .code
        }
        
        // Link patterns
        if lower.hasPrefix("http") || lower.contains("://") || lower.contains(".com") ||
           lower.contains(".io") || lower.contains(".dev") {
            return .link
        }
        
        // Meeting patterns
        if lower.contains("meeting") || lower.contains("reunión") || lower.contains("agenda") ||
           lower.contains("standup") || lower.contains("sync") {
            return .meeting
        }
        
        // Reminder patterns
        if lower.contains("recordar") || lower.contains("remind") || lower.contains("alarm") ||
           lower.contains("a las") || lower.contains("at ") {
            return .reminder
        }
        
        return .idea
    }
    
    /// Detect template based on active app
    private func detectTemplate() {
        let app = NervousSystem.shared.activeAppName.lowercased()
        if app.contains("xcode") || app.contains("code") || app.contains("terminal") {
            currentTemplate = .code
        } else if app.contains("zoom") || app.contains("teams") || app.contains("meet") {
            currentTemplate = .meeting
        } else if app.contains("safari") || app.contains("chrome") || app.contains("firefox") {
            currentTemplate = .link
        } else {
            currentTemplate = .idea
        }
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Persistence
    // ═══════════════════════════════════════════════════
    
    private func persistNotes() {
        guard let data = try? JSONEncoder().encode(recentNotes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let notes = try? JSONDecoder().decode([QuickNote].self, from: data) else { return }
        recentNotes = notes
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - Apple Notes Export
    // ═══════════════════════════════════════════════════
    
    private func exportToAppleNotes(_ note: QuickNote) {
        let folder = note.category.rawValue
        let body = "\(note.icon) \(note.text)\n\n📍 \(note.appContext) · \(note.timestamp.formatted())"
        
        let script = """
        tell application "Notes"
            tell account "iCloud"
                if not (exists folder "\(folder)") then
                    make new folder with properties {name:"\(folder)"}
                end if
                tell folder "\(folder)"
                    make new note with properties {body:"\(body)"}
                end tell
            end tell
        end tell
        """
        
        Task.detached {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    await MainActor.run {
                        self.log.warning("Apple Notes export failed: \(error)")
                    }
                }
            }
        }
    }
}
