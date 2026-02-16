import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📝 Quick Notes Manager
// ═══════════════════════════════════════════════════
// Floating scratchpad that drops from the notch.
// Persists via UserDefaults (SwiftData would be overkill here).
// Supports multiple notes with quick switching.

@MainActor
final class QuickNotesManager: ObservableObject {
    static let shared = QuickNotesManager()
    
    // ── Published State ──
    @Published var notes: [QuickNote] = []
    @Published var activeNoteIndex: Int = 0
    @Published var isVisible = false
    
    // ── Persistence Key ──
    private let storageKey = "livenotch.quicknotes"
    private var saveTimer: Timer?
    
    var activeNote: QuickNote? {
        guard activeNoteIndex >= 0, activeNoteIndex < notes.count else { return nil }
        return notes[activeNoteIndex]
    }
    
    private init() {
        loadNotes()
        if notes.isEmpty {
            createNote(title: "Quick Note")
        }
    }
    
    deinit {
        saveTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - CRUD
    // ════════════════════════════════════════
    
    func createNote(title: String = "New Note") {
        let note = QuickNote(title: title)
        notes.insert(note, at: 0)
        activeNoteIndex = 0
        saveNotes()
    }
    
    func updateContent(_ content: String) {
        guard activeNoteIndex < notes.count else { return }
        notes[activeNoteIndex].content = content
        notes[activeNoteIndex].updatedAt = Date()
        saveNotes()
    }
    
    func updateTitle(_ title: String) {
        guard activeNoteIndex < notes.count else { return }
        notes[activeNoteIndex].title = title
        saveNotes()
    }
    
    func deleteNote(at index: Int) {
        guard notes.count > 1, index < notes.count else { return }
        notes.remove(at: index)
        if activeNoteIndex >= notes.count {
            activeNoteIndex = max(0, notes.count - 1)
        }
        saveNotes()
    }
    
    func selectNote(at index: Int) {
        guard index >= 0, index < notes.count else { return }
        activeNoteIndex = index
    }
    
    // ════════════════════════════════════════
    // MARK: - Toggle
    // ════════════════════════════════════════
    
    func toggle() {
        withAnimation(DS.Anim.springStd) {
            isVisible.toggle()
        }
        if isVisible {
            HapticManager.shared.play(.toggle)
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Persistence
    // ════════════════════════════════════════
    
    private func saveNotes() {
        // Throttle: debounce saves to max every 0.5s
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            NotchPersistence.shared.setCodable(.quickNotes, value: self.notes)
        }
    }
    
    private func saveNotesImmediately() {
        saveTimer?.invalidate()
        NotchPersistence.shared.setCodable(.quickNotes, value: notes)
    }
    
    private func loadNotes() {
        if let decoded = NotchPersistence.shared.getCodable(.quickNotes, as: [QuickNote].self) {
            notes = decoded
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Helpers
    // ════════════════════════════════════════
    
    var wordCount: Int {
        activeNote?.content.split(separator: " ").count ?? 0
    }
    
    var charCount: Int {
        activeNote?.content.count ?? 0
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Data Model
// ═══════════════════════════════════════════════════

struct QuickNote: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    
    init(title: String = "New Note", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
    }
    
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty note" }
        return String(trimmed.prefix(50))
    }
    
    var timeAgo: String {
        let diff = Date().timeIntervalSince(updatedAt)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
