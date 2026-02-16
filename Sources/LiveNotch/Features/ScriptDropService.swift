import Foundation
import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - ⚡ Script Drop Service — Execute from the Notch
// ═══════════════════════════════════════════════════
//
// Drop any script (.sh, .py, .scpt, .js, .rb, .zsh, .swift...)
// onto the Notch → it executes and shows live output.
//
// Features:
//   • Script type detection (icon, color, interpreter)
//   • Live stdout/stderr streaming
//   • Execution history with status
//   • Favorite scripts for quick re-run
//   • Safety gate — confirms before execution
//   • Kill running script support
//
// Security:
//   Uses Process (fork+exec) — inherits user permissions.
//   No sandbox escape, no privilege escalation.
//   Scripts run with current user's environment.
//

@MainActor
final class ScriptDropService: ObservableObject {
    static let shared = ScriptDropService()
    
    // ── Supported Script Types ──
    enum ScriptType: String, CaseIterable {
        case shell       = "sh"
        case zsh         = "zsh"
        case bash        = "bash"
        case command     = "command"
        case python      = "py"
        case javascript  = "js"
        case ruby        = "rb"
        case swift       = "swift"
        case applescript = "scpt"
        case osascript   = "applescript"
        
        var icon: String {
            switch self {
            case .shell, .zsh, .bash, .command: return "terminal.fill"
            case .python:      return "chevron.left.forwardslash.chevron.right"
            case .javascript:  return "curlybraces"
            case .ruby:        return "diamond.fill"
            case .swift:       return "swift"
            case .applescript, .osascript: return "applescript.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .shell, .zsh, .bash, .command: return .green
            case .python:      return .yellow
            case .javascript:  return .orange
            case .ruby:        return .red
            case .swift:       return .orange
            case .applescript, .osascript: return .blue
            }
        }
        
        var interpreter: String {
            switch self {
            case .shell:       return "/bin/sh"
            case .zsh:         return "/bin/zsh"
            case .bash:        return "/bin/bash"
            case .command:     return "/bin/sh"
            case .python:      return "/usr/bin/env python3"
            case .javascript:  return "/usr/bin/env node"
            case .ruby:        return "/usr/bin/env ruby"
            case .swift:       return "/usr/bin/env swift"
            case .applescript, .osascript: return "/usr/bin/osascript"
            }
        }
        
        var label: String {
            switch self {
            case .shell:       return "Shell"
            case .zsh:         return "Zsh"
            case .bash:        return "Bash"
            case .command:     return "Command"
            case .python:      return "Python"
            case .javascript:  return "Node.js"
            case .ruby:        return "Ruby"
            case .swift:       return "Swift"
            case .applescript, .osascript: return "AppleScript"
            }
        }
    }
    
    // ── Execution State ──
    enum ExecutionState: Equatable {
        case idle
        case confirming     // Waiting user confirmation
        case running        // Script is executing
        case success        // Finished with exit 0
        case failed(Int32)  // Finished with non-zero exit
        case killed         // User terminated
    }
    
    // ── History Item ──
    struct ScriptRecord: Identifiable, Codable {
        let id: UUID
        let name: String
        let path: String
        let type: String
        let executedAt: Date
        let exitCode: Int32
        let durationMs: Int
        var isFavorite: Bool
        
        var isSuccess: Bool { exitCode == 0 }
        
        var timeAgo: String {
            let interval = Date().timeIntervalSince(executedAt)
            if interval < 60 { return "just now" }
            if interval < 3600 { return "\(Int(interval/60))m ago" }
            if interval < 86400 { return "\(Int(interval/3600))h ago" }
            return "\(Int(interval/86400))d ago"
        }
    }
    
    // ── Published State ──
    @Published var state: ExecutionState = .idle
    @Published var pendingScript: URL? = nil
    @Published var pendingScriptType: ScriptType? = nil
    @Published var outputLines: [OutputLine] = []
    @Published var history: [ScriptRecord] = []
    @Published var isDropHovering: Bool = false
    @Published var elapsedMs: Int = 0
    
    struct OutputLine: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
        let timestamp: Date = Date()
    }
    
    // ── Private ──
    private var runningProcess: Process?
    private var startTime: Date?
    private var elapsedTimer: Timer?
    private let maxOutputLines = 200
    private let historyKey = "ScriptDrop_History"
    private let maxHistory = 50
    
    // ── Init ──
    private init() {
        loadHistory()
    }
    
    deinit {
        elapsedTimer?.invalidate()
        runningProcess?.terminate()
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Detection
    // ═══════════════════════════════════════════
    
    /// Check if a URL is an executable script
    static func isScript(_ url: URL) -> Bool {
        return scriptType(for: url) != nil
    }
    
    /// Determine script type from file extension
    static func scriptType(for url: URL) -> ScriptType? {
        let ext = url.pathExtension.lowercased()
        return ScriptType.allCases.first { $0.rawValue == ext }
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Drop Handling
    // ═══════════════════════════════════════════
    
    /// Called when a script is dropped on the notch
    func handleDrop(_ url: URL) {
        guard let type = Self.scriptType(for: url) else {
            NSLog("⚡ ScriptDrop: Not a recognized script: \(url.pathExtension)")
            return
        }
        
        // If already running, reject
        guard state != .running else {
            HapticManager.shared.play(.error)
            appendOutput("⚠️ A script is already running. Kill it first.", isError: true)
            return
        }
        
        pendingScript = url
        pendingScriptType = type
        state = .confirming
        outputLines = []
        
        NSLog("⚡ ScriptDrop: Ready to execute \(url.lastPathComponent) (\(type.label))")
        HapticManager.shared.play(.drop)
        
        NotificationCenter.default.post(name: .scriptDropReady, object: url.lastPathComponent)
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Execution
    // ═══════════════════════════════════════════
    
    /// User confirmed — execute the script
    func confirmAndRun() {
        guard let url = pendingScript,
              let type = pendingScriptType else { return }
        
        state = .running
        outputLines = []
        startTime = Date()
        elapsedMs = 0
        
        appendOutput("▶ Executing \(url.lastPathComponent)...", isError: false)
        appendOutput("  Type: \(type.label) | Interpreter: \(type.interpreter)", isError: false)
        appendOutput("─────────────────────────────────────", isError: false)
        
        HapticManager.shared.play(.heavy)
        
        // Start elapsed timer
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            }
        }
        
        // Execute in background
        Task.detached { [weak self] in
            await self?.executeScript(url: url, type: type)
        }
    }
    
    /// Cancel the pending confirmation
    func cancelPending() {
        state = .idle
        pendingScript = nil
        pendingScriptType = nil
        HapticManager.shared.play(.toggle)
    }
    
    /// Kill the running script
    func killScript() {
        guard state == .running, let process = runningProcess else { return }
        
        process.terminate()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        state = .killed
        appendOutput("─────────────────────────────────────", isError: false)
        appendOutput("⛔ Script terminated by user", isError: true)
        
        HapticManager.shared.play(.error)
        
        if let url = pendingScript {
            addToHistory(name: url.lastPathComponent, path: url.path,
                        type: pendingScriptType?.rawValue ?? "sh",
                        exitCode: -9, durationMs: elapsedMs)
        }
        
        NSLog("⚡ ScriptDrop: Killed running script")
    }
    
    /// Re-run a script from history
    func rerun(_ record: ScriptRecord) {
        let url = URL(fileURLWithPath: record.path)
        guard FileManager.default.fileExists(atPath: record.path) else {
            appendOutput("❌ Script not found: \(record.path)", isError: true)
            HapticManager.shared.play(.error)
            return
        }
        handleDrop(url)
    }
    
    /// Toggle favorite status on a history record
    func toggleFavorite(_ record: ScriptRecord) {
        if let idx = history.firstIndex(where: { $0.id == record.id }) {
            history[idx].isFavorite.toggle()
            saveHistory()
        }
        HapticManager.shared.play(.toggle)
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Private Execution
    // ═══════════════════════════════════════════
    
    private func executeScript(url: URL, type: ScriptType) async {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        // Determine interpreter
        let interpreterParts = type.interpreter.split(separator: " ")
        if interpreterParts.count > 1 {
            // e.g. "/usr/bin/env python3"
            process.executableURL = URL(fileURLWithPath: String(interpreterParts[0]))
            process.arguments = Array(interpreterParts.dropFirst().map(String.init)) + [url.path]
        } else {
            process.executableURL = URL(fileURLWithPath: type.interpreter)
            process.arguments = [url.path]
        }
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.currentDirectoryURL = url.deletingLastPathComponent()
        
        // Inherit user's environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        process.environment = env
        
        await MainActor.run {
            self.runningProcess = process
        }
        
        // Stream stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                for line in lines {
                    self?.appendOutput(line, isError: false)
                }
            }
        }
        
        // Stream stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                for line in lines {
                    self?.appendOutput(line, isError: true)
                }
            }
        }
        
        // Run
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            await MainActor.run {
                appendOutput("❌ Failed to launch: \(error.localizedDescription)", isError: true)
                state = .failed(-1)
                elapsedTimer?.invalidate()
                elapsedTimer = nil
                HapticManager.shared.play(.error)
            }
            return
        }
        
        // Cleanup
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        
        let exitCode = process.terminationStatus
        let duration = self.elapsedMs
        
        await MainActor.run {
            elapsedTimer?.invalidate()
            elapsedTimer = nil
            runningProcess = nil
            
            appendOutput("─────────────────────────────────────", isError: false)
            
            if exitCode == 0 {
                state = .success
                appendOutput("✅ Finished in \(formatDuration(duration))", isError: false)
                HapticManager.shared.play(.success)
            } else {
                state = .failed(exitCode)
                appendOutput("❌ Exited with code \(exitCode) (\(formatDuration(duration)))", isError: true)
                HapticManager.shared.play(.error)
            }
            
            addToHistory(
                name: url.lastPathComponent,
                path: url.path,
                type: type.rawValue,
                exitCode: exitCode,
                durationMs: duration
            )
            
            NotificationCenter.default.post(name: .scriptDropFinished, object: exitCode)
        }
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Output Helpers
    // ═══════════════════════════════════════════
    
    private func appendOutput(_ text: String, isError: Bool) {
        let line = OutputLine(text: text, isError: isError)
        outputLines.append(line)
        
        // Trim if too many lines
        if outputLines.count > maxOutputLines {
            outputLines.removeFirst(outputLines.count - maxOutputLines)
        }
    }
    
    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }
    
    // ═══════════════════════════════════════════
    // MARK: - History Persistence
    // ═══════════════════════════════════════════
    
    private func addToHistory(name: String, path: String, type: String, exitCode: Int32, durationMs: Int) {
        let record = ScriptRecord(
            id: UUID(),
            name: name,
            path: path,
            type: type,
            executedAt: Date(),
            exitCode: exitCode,
            durationMs: durationMs,
            isFavorite: false
        )
        history.insert(record, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        saveHistory()
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let loaded = try? JSONDecoder().decode([ScriptRecord].self, from: data) else { return }
        history = loaded
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Computed Properties
    // ═══════════════════════════════════════════
    
    var favorites: [ScriptRecord] {
        history.filter { $0.isFavorite }
    }
    
    var recentScripts: [ScriptRecord] {
        Array(history.prefix(10))
    }
    
    var isRunning: Bool { state == .running }
    
    var stateColor: Color {
        switch state {
        case .idle:        return .gray
        case .confirming:  return .yellow
        case .running:     return .cyan
        case .success:     return .green
        case .failed:      return .red
        case .killed:      return .orange
        }
    }
    
    var stateIcon: String {
        switch state {
        case .idle:        return "terminal"
        case .confirming:  return "exclamationmark.triangle.fill"
        case .running:     return "gearshape.2.fill"
        case .success:     return "checkmark.circle.fill"
        case .failed:      return "xmark.octagon.fill"
        case .killed:      return "stop.circle.fill"
        }
    }
    
    var elapsedDisplay: String {
        formatDuration(elapsedMs)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Notification Names
// ═══════════════════════════════════════════════════

extension Notification.Name {
    static let scriptDropReady     = Notification.Name("notch.scriptDrop.ready")
    static let scriptDropFinished  = Notification.Name("notch.scriptDrop.finished")
}
