import Foundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🧠 Brain Dump — Quick Capture + AI Categorization
// ═══════════════════════════════════════════════════
// Inspired by Notchable ($20) — but FREE and with local AI

final class BrainDumpManager: ObservableObject {
    static let shared = BrainDumpManager()
    
    enum Category: String, CaseIterable {
        case work = "💼 Work"
        case dev = "⚡ Dev"
        case personal = "🏠 Personal"
        case health = "🏃 Health"
        case idea = "💡 Idea"
        case reminder = "⏰ Reminder"
        case shopping = "🛒 Shopping"
        case urgent = "🔴 Urgent"
        
        var color: String {
            switch self {
            case .work: return "blue"
            case .dev: return "cyan"
            case .personal: return "green"
            case .health: return "orange"
            case .idea: return "purple"
            case .reminder: return "yellow"
            case .shopping: return "teal"
            case .urgent: return "red"
            }
        }
        
        var emoji: String {
            String(rawValue.prefix(2))
        }
    }
    
    struct BrainItem: Identifiable, Codable {
        let id: UUID
        var text: String
        var categoryRaw: String
        var isDone: Bool
        let timestamp: Date
        var priority: Int // 1=urgent, 2=normal, 3=low
        
        var category: Category {
            Category(rawValue: categoryRaw) ?? .personal
        }
        
        init(text: String, category: Category, priority: Int = 2) {
            self.id = UUID()
            self.text = text
            self.categoryRaw = category.rawValue
            self.isDone = false
            self.timestamp = Date()
            self.priority = priority
        }
        
        var timeAgo: String {
            let seconds = Date().timeIntervalSince(timestamp)
            if seconds < 60 { return "now" }
            if seconds < 3600 { return "\(Int(seconds / 60))m" }
            if seconds < 86400 { return "\(Int(seconds / 3600))h" }
            return "\(Int(seconds / 86400))d"
        }
    }
    
    @Published var items: [BrainItem] = []
    @Published var isInputActive = false
    
    private let saveKey = "braindump_items"
    
    private init() {
        loadItems()
    }
    
    var sortedItems: [BrainItem] {
        items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            if a.priority != b.priority { return a.priority < b.priority }
            return a.timestamp > b.timestamp
        }
    }
    
    func categorize(_ text: String) -> (String, Category, Int) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleanText.lowercased()
        
        // Manual Override Prefixes
        if lower.hasPrefix("w:") || lower.hasPrefix("work:") { return (cleanWrapper(cleanText), .work, 2) }
        if lower.hasPrefix("d:") || lower.hasPrefix("dev:") { return (cleanWrapper(cleanText), .dev, 2) }
        if lower.hasPrefix("h:") || lower.hasPrefix("health:") { return (cleanWrapper(cleanText), .health, 2) }
        if lower.hasPrefix("s:") || lower.hasPrefix("shop:") { return (cleanWrapper(cleanText), .shopping, 3) }
        if lower.hasPrefix("i:") || lower.hasPrefix("idea:") { return (cleanWrapper(cleanText), .idea, 3) }
        if lower.hasPrefix("r:") || lower.hasPrefix("remind:") { return (cleanWrapper(cleanText), .reminder, 2) }
        if lower.hasPrefix("!:") || lower.hasPrefix("urgent:") { return (cleanWrapper(cleanText), .urgent, 1) }
        
        // Urgency detection
        let urgentKeywords = ["urgent", "urgente", "asap", "now", "ahora", "inmediato",
                              "emergency", "critical", "blocking", "blocker", "hotfix",
                              "p0", "broken", "down", "outage", "crashea", "roto"]
        if urgentKeywords.contains(where: { lower.contains($0) }) {
            return (cleanText, .urgent, 1)
        }
        
        // Category keyword matching
        let devKeywords = ["bug", "fix", "deploy", "code", "commit", "push", "merge",
                           "pr", "pull request", "branch", "refactor", "test", "lint",
                           "build", "api", "endpoint", "database", "migration", "schema",
                           "docker", "ci", "cd", "pipeline", "debug", "crash", "error",
                           "swift", "react", "node", "npm", "xcode", "git", "repo",
                           "función", "variable", "compilar", "servidor", "release"]
        
        let workKeywords = ["meeting", "email", "call", "project", "review", "deadline",
                            "reunión", "correo", "llamar", "proyecto", "cliente", "report",
                            "slack", "sprint", "standup", "jira", "ticket", "task",
                            "presentation", "presentación", "invoice", "factura", "contract",
                            "proposal", "propuesta", "pitch", "demo", "sync", "1:1"]
        
        let healthKeywords = ["gym", "run", "doctor", "medicine", "pills", "exercise",
                              "yoga", "meditate", "médico", "pastilla", "ejercicio",
                              "correr", "agua", "dormir", "sleep", "walk", "stretch",
                              "vitamins", "appointment", "cita", "dentist", "therapy",
                              "weight", "diet", "dieta", "workout", "rest", "descanso"]
        
        let shoppingKeywords = ["buy", "comprar", "get", "groceries", "order", "amazon",
                                "milk", "bread", "leche", "pan", "supermercado", "tienda",
                                "store", "pick up", "recoger", "enviar", "devolver",
                                "return", "refund", "precio", "price", "mercado"]
        
        let ideaKeywords = ["idea", "what if", "maybe", "could", "would be cool", "try",
                            "experiment", "feature", "design", "concept", "prototype",
                            "brainstorm", "explore", "research", "investigate", "probar",
                            "inventar", "crear", "crear", "imaginar", "sketch", "wireframe"]
        
        let reminderKeywords = ["remember", "don't forget", "remind", "recordar",
                                "no olvidar", "note", "tomorrow", "mañana", "tonight",
                                "later", "después", "check", "verify", "confirm",
                                "follow up", "seguimiento", "pendiente", "avisar"]
        
        if devKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .dev, 2) }
        if workKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .work, 2) }
        if healthKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .health, 2) }
        if shoppingKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .shopping, 3) }
        if ideaKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .idea, 3) }
        if reminderKeywords.contains(where: { lower.contains($0) }) { return (cleanText, .reminder, 2) }
        
        return (cleanText, .personal, 2)
    }
    
    private func cleanWrapper(_ text: String) -> String {
        guard let idx = text.firstIndex(of: ":") else { return text }
        return String(text[text.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
    }
    
    func addItem(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let (cleanText, category, priority) = categorize(text)
        let item = BrainItem(text: cleanText, category: category, priority: priority)
        items.insert(item, at: 0)
        saveItems()
        HapticManager.shared.play(.success)
    }
    
    func toggleDone(_ item: BrainItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isDone.toggle()
            saveItems()
        }
    }
    
    func removeItem(_ item: BrainItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func clearDone() {
        items.removeAll { $0.isDone }
        saveItems()
    }
    
    var activeCount: Int { items.filter { !$0.isDone }.count }
    var urgentCount: Int { items.filter { !$0.isDone && $0.priority == 1 }.count }
    
    // ── Persistence ──
    private func saveItems() {
        NotchPersistence.shared.setCodable(.brainDumpItems, value: items)
    }
    
    private func loadItems() {
        if let decoded = NotchPersistence.shared.getCodable(.brainDumpItems, as: [BrainItem].self) {
            items = decoded
        }
    }
}
