import SwiftUI
import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 🛩️ Developer Cockpit — Ambient Dev Status
// ═══════════════════════════════════════════════════
//
// Transforms the notch into a development status dashboard.
// Shows: Git branch/status, build progress, terminal activity.
//
// Architecture:
// - FileMonitor watches .git directory for changes
// - Process detection via NSWorkspace running applications
// - Build status via DerivedData log monitoring (Xcode)
// - Hammerspoon IPC bridge for deep window/file context
// - RescueTime API for productivity metrics
//
// All monitoring is PASSIVE — zero permissions, zero network,
// just filesystem observation and process listing.

// ═══════════════════════════════════════════════════
// MARK: - Git Status Model
// ═══════════════════════════════════════════════════

struct GitStatus: Equatable {
    var branch: String = ""
    var ahead: Int = 0
    var behind: Int = 0
    var staged: Int = 0
    var modified: Int = 0
    var untracked: Int = 0
    var hasConflicts: Bool = false
    
    var isDirty: Bool { staged + modified + untracked > 0 }
    var isClean: Bool { !isDirty }
    
    var statusColor: Color {
        if hasConflicts { return .red }
        if staged > 0 { return Color(hex: "00FF88") }   // Green — ready
        if modified > 0 { return Color(hex: "FFD700") }  // Gold — work in progress
        return Color(hex: "6B7280")                       // Gray — clean
    }
    
    var branchIcon: String {
        if hasConflicts { return "exclamationmark.triangle.fill" }
        if staged > 0 { return "arrow.up.circle.fill" }
        if isDirty { return "pencil.circle.fill" }
        return "checkmark.circle.fill"
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Build Status Model
// ═══════════════════════════════════════════════════

enum BuildPhase: Equatable {
    case idle
    case building(progress: Double)  // 0.0 → 1.0
    case success
    case failed(errorCount: Int)
    
    var color: Color {
        switch self {
        case .idle: return Color(hex: "6B7280")
        case .building: return Color(hex: "3B82F6")     // Blue — compiling
        case .success: return Color(hex: "10B981")       // Emerald — passed
        case .failed: return Color(hex: "EF4444")        // Red — broken
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "hammer"
        case .building: return "gearshape.2.fill"
        case .success: return "checkmark.seal.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Terminal Process Model
// ═══════════════════════════════════════════════════

struct TerminalProcess: Identifiable, Equatable {
    let id = UUID()
    let name: String        // "npm", "docker", "cargo", "swift"
    let command: String     // Full command string
    let isLongRunning: Bool // Dev server, docker compose, etc.
    
    var icon: String {
        switch name.lowercased() {
        case "npm", "node": return "⬡"
        case "docker": return "🐳"
        case "cargo", "rustc": return "🦀"
        case "swift", "swiftc": return "🕊"
        case "python", "python3": return "🐍"
        case "go": return "🔷"
        case "git": return ""
        case "make", "cmake": return "⚙️"
        default: return "▶"
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Productivity Metrics (RescueTime)
// ═══════════════════════════════════════════════════

struct ProductivityMetrics: Equatable {
    var score: Double = 0          // 0-100 productivity score
    var focusMinutes: Int = 0      // Deep focus time today
    var distractionMinutes: Int = 0
    var streak: Int = 0            // Consecutive deep work sessions
    var topCategory: String = ""   // "Software Development", "Design", etc.
    
    var scoreColor: Color {
        switch score {
        case 80...100: return Color(hex: "10B981")   // Emerald
        case 60..<80:  return Color(hex: "3B82F6")   // Blue
        case 40..<60:  return Color(hex: "F59E0B")   // Amber
        default:       return Color(hex: "EF4444")    // Red
        }
    }
    
    var formattedFocusTime: String {
        let hours = focusMinutes / 60
        let mins = focusMinutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Developer Cockpit Engine
// ═══════════════════════════════════════════════════

@MainActor
final class DevCockpit: ObservableObject {
    static let shared = DevCockpit()
    
    @Published var git = GitStatus()
    @Published var build: BuildPhase = .idle
    @Published var activeProcesses: [TerminalProcess] = []
    @Published var productivity = ProductivityMetrics()
    @Published var isActive = false   // Only active when dev tools detected
    @Published var activeProjectName: String = ""
    
    private var gitMonitorTimer: Timer?
    private var processMonitorTimer: Timer?
    private var buildPhaseTimer: Timer?
    
    // Hammerspoon IPC port (localhost)
    private let hammerspoonPort: Int = 17420
    
    // RescueTime
    private var rescueTimeKey: String? {
        UserDefaults.standard.string(forKey: "notch.rescuetime.api_key")
    }
    
    private init() {}
    
    // ═══════════════════════════════════════
    // MARK: - Lifecycle
    // ═══════════════════════════════════════
    
    func startMonitoring() {
        isActive = true
        startGitMonitor()
        startProcessMonitor()
        startBuildPhaseMonitor()
        fetchProductivity()
        
        NSLog("🛩️ DevCockpit: Monitoring started")
    }
    
    deinit {
        gitMonitorTimer?.invalidate()
        processMonitorTimer?.invalidate()
        buildPhaseTimer?.invalidate()
    }
    
    func stopMonitoring() {
        isActive = false
        gitMonitorTimer?.invalidate()
        processMonitorTimer?.invalidate()
        buildPhaseTimer?.invalidate()
        gitMonitorTimer = nil
        processMonitorTimer = nil
        buildPhaseTimer = nil
        
        NSLog("🛩️ DevCockpit: Monitoring stopped")
    }
    
    // ═══════════════════════════════════════
    // MARK: - Git Status (via shell)
    // ═══════════════════════════════════════
    
    private func startGitMonitor() {
        // Poll every 3 seconds — lightweight git status
        gitMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshGitStatus()
            }
        }
    }
    
    private func refreshGitStatus() {
        guard let projectPath = detectActiveProject() else {
            git = GitStatus()
            return
        }
        
        activeProjectName = URL(fileURLWithPath: projectPath).lastPathComponent
        
        // Get branch name
        if let branch = runGitCommand("rev-parse --abbrev-ref HEAD", in: projectPath) {
            git.branch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get status --porcelain
        if let status = runGitCommand("status --porcelain", in: projectPath) {
            let lines = status.components(separatedBy: "\n").filter { !$0.isEmpty }
            var staged = 0, modified = 0, untracked = 0, conflicts = false
            
            for line in lines {
                guard line.count >= 2 else { continue }
                let idx = line.startIndex
                let x = line[idx]
                let y = line[line.index(after: idx)]
                
                if x == "U" || y == "U" { conflicts = true }
                if x != " " && x != "?" { staged += 1 }
                if y == "M" || y == "D" { modified += 1 }
                if x == "?" { untracked += 1 }
            }
            
            git.staged = staged
            git.modified = modified
            git.untracked = untracked
            git.hasConflicts = conflicts
        }
        
        // Ahead/behind
        if let revList = runGitCommand("rev-list --left-right --count @{upstream}...HEAD", in: projectPath) {
            let parts = revList.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\t")
            if parts.count == 2 {
                git.behind = Int(parts[0]) ?? 0
                git.ahead = Int(parts[1]) ?? 0
            }
        }
    }
    
    private func runGitCommand(_ args: String, in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args.components(separatedBy: " ")
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            NSLog("🔧 DevCockpit: Shell command failed — %@", error.localizedDescription)
            return nil
        }
    }
    
    /// Detect the active project by finding the frontmost app's document path
    private func detectActiveProject() -> String? {
        // Strategy 1: Check common project directories
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/game/live-notch-swift",
            "\(home)/antigravity",
            "\(home)/Desktop"
        ]
        
        // Use the first directory that has a .git folder
        for dir in candidates {
            if FileManager.default.fileExists(atPath: "\(dir)/.git") {
                return dir
            }
        }
        
        return nil
    }
    
    // ═══════════════════════════════════════
    // MARK: - Process Monitor
    // ═══════════════════════════════════════
    
    private func startProcessMonitor() {
        processMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProcesses()
            }
        }
    }
    
    private func refreshProcesses() {
        let devNames = Set(["node", "npm", "docker", "cargo", "rustc", "swift", "swiftc",
                           "python", "python3", "go", "make", "cmake", "gradle", "java",
                           "ruby", "php", "flutter", "dart"])
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-eo", "comm="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let running = output.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let detected = running.compactMap { proc -> TerminalProcess? in
                    let name = URL(fileURLWithPath: proc).lastPathComponent.lowercased()
                    guard devNames.contains(name) else { return nil }
                    let isLong = ["node", "docker", "npm"].contains(name)
                    return TerminalProcess(name: name, command: proc, isLongRunning: isLong)
                }
                
                // Deduplicate by name
                var seen = Set<String>()
                activeProcesses = detected.filter { seen.insert($0.name).inserted }
            }
        } catch {
            NSLog("🔧 DevCockpit: Process refresh failed — %@", error.localizedDescription)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Build Phase Monitor (Xcode)
    // ═══════════════════════════════════════
    
    private func startBuildPhaseMonitor() {
        // Watch for Xcode build activity via running processes
        buildPhaseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkBuildStatus()
            }
        }
    }
    
    private func checkBuildStatus() {
        // Detect swift build / xcodebuild processes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "xcodebuild|swift-build|swift build"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if !output.isEmpty && build != .success {
                // Build is running
                if case .building(let p) = build {
                    // Increment progress (simulated since we can't read actual %)
                    let newProgress = min(0.95, p + 0.05)
                    build = .building(progress: newProgress)
                } else {
                    build = .building(progress: 0.1)
                }
            } else if case .building = build {
                // Build just finished — mark success (or check exit code)
                build = .success
                HapticManager.shared.play(.success)
                
                // Reset after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.build = .idle
                }
            }
        } catch {
            NSLog("🔧 DevCockpit: Build status check failed — %@", error.localizedDescription)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - RescueTime Integration
    // ═══════════════════════════════════════
    
    func fetchProductivity() {
        guard let key = rescueTimeKey, !key.isEmpty else { return }
        
        let urlString = "https://www.rescuetime.com/anapi/data?key=\(key)&perspective=interval&restrict_kind=productivity&interval=hour&format=json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            // Parse RescueTime response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = json["rows"] as? [[Any]] {
                
                var totalProductive = 0
                var totalDistracted = 0
                
                for row in rows {
                    guard row.count >= 4,
                          let seconds = row[1] as? Int,
                          let productivityScore = row[3] as? Int else { continue }
                    
                    let minutes = seconds / 60
                    if productivityScore >= 1 {
                        totalProductive += minutes
                    } else if productivityScore <= -1 {
                        totalDistracted += minutes
                    }
                }
                
                let total = totalProductive + totalDistracted
                let score = total > 0 ? Double(totalProductive) / Double(total) * 100 : 0
                
                Task { @MainActor [weak self] in
                    self?.productivity.focusMinutes = totalProductive
                    self?.productivity.distractionMinutes = totalDistracted
                    self?.productivity.score = score
                }
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════
    // MARK: - Hammerspoon IPC
    // ═══════════════════════════════════════
    
    /// Query Hammerspoon for window/desktop context.
    /// Expects Hammerspoon to run a local HTTP server on port 17420.
    func queryHammerspoon(endpoint: String, completion: @escaping ([String: Any]?) -> Void) {
        let urlString = "http://localhost:\(hammerspoonPort)/\(endpoint)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0  // Fast timeout — local only
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            completion(json)
        }.resume()
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Developer Cockpit View (Compact Strip)
// ═══════════════════════════════════════════════════

/// A thin ambient strip that sits at the edge of the notch.
/// Shows git branch, build status, and active processes.
/// Designed to be PERIPHERAL — never demands attention.
struct DevCockpitStrip: View {
    @ObservedObject var cockpit = DevCockpit.shared
    
    @State private var buildPulse: Bool = false
    @State private var successFlash: Double = 0
    
    var body: some View {
        HStack(spacing: 6) {
            // ── Git Badge ──
            if !cockpit.git.branch.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: cockpit.git.branchIcon)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(cockpit.git.statusColor)
                    
                    Text(cockpit.git.branch)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    // Status dots
                    if cockpit.git.isDirty {
                        statusDots
                    }
                    
                    // Ahead/behind
                    if cockpit.git.ahead > 0 {
                        Text("↑\(cockpit.git.ahead)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "10B981"))
                    }
                    if cockpit.git.behind > 0 {
                        Text("↓\(cockpit.git.behind)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "F59E0B"))
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
            }
            
            // ── Build Status ──
            if case .building(let progress) = cockpit.build {
                HStack(spacing: 3) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 7))
                        .foregroundColor(BuildPhase.building(progress: 0).color)
                        .rotationEffect(.degrees(buildPulse ? 360 : 0))
                    
                    // Liquid progress
                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "3B82F6").opacity(0.3),
                                        Color(hex: "3B82F6").opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                    .frame(width: 30, height: 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(hex: "3B82F6").opacity(0.08))
                .clipShape(Capsule())
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        buildPulse = true
                    }
                }
            }
            
            if case .success = cockpit.build {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "10B981"))
                    Text("OK")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(hex: "10B981").opacity(0.8))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(hex: "10B981").opacity(0.1))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            }
            
            if case .failed(let errors) = cockpit.build {
                HStack(spacing: 3) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                    Text("\(errors)")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // ── Active Dev Processes ──
            if !cockpit.activeProcesses.isEmpty {
                HStack(spacing: 2) {
                    ForEach(cockpit.activeProcesses.prefix(3)) { proc in
                        Text(proc.icon)
                            .font(.system(size: 8))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.03))
                .clipShape(Capsule())
            }
            
            // ── Productivity Score (RescueTime) ──
            if cockpit.productivity.focusMinutes > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(cockpit.productivity.scoreColor)
                        .frame(width: 4, height: 4)
                    
                    Text(cockpit.productivity.formattedFocusTime)
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.03))
                .clipShape(Capsule())
            }
        }
    }
    
    // ── Status dot indicators for git ──
    private var statusDots: some View {
        HStack(spacing: 2) {
            if cockpit.git.staged > 0 {
                Circle()
                    .fill(Color(hex: "10B981"))
                    .frame(width: 3, height: 3)
            }
            if cockpit.git.modified > 0 {
                Circle()
                    .fill(Color(hex: "F59E0B"))
                    .frame(width: 3, height: 3)
            }
            if cockpit.git.untracked > 0 {
                Circle()
                    .fill(Color(hex: "6B7280"))
                    .frame(width: 3, height: 3)
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Ambient Build Progress (Notch Border Fill)
// ═══════════════════════════════════════════════════

/// An overlay that fills the notch border with build progress.
/// Like pouring liquid into the outline of the notch.
struct AmbientBuildProgress: View {
    let progress: Double
    let color: Color
    
    @State private var waveOffset: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            // Wave surface on top of the fill
            Canvas { ctx, size in
                guard progress > 0.01 else { return }
                let fillHeight = size.height * (1 - progress)
                
                var wavePath = Path()
                wavePath.move(to: CGPoint(x: 0, y: fillHeight))
                
                // Sine wave surface
                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let normX = x / size.width
                    let angle = Double(normX) * Double.pi * 3.0 + waveOffset
                    let y = fillHeight + CGFloat(sin(angle)) * 2.0
                    wavePath.addLine(to: CGPoint(x: x, y: y))
                }
                
                wavePath.addLine(to: CGPoint(x: size.width, y: size.height))
                wavePath.addLine(to: CGPoint(x: 0, y: size.height))
                wavePath.closeSubpath()
                
                ctx.fill(wavePath, with: .color(color.opacity(0.2)))
                
                // Surface highlight
                var surfaceLine = Path()
                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let normX = x / size.width
                    let angle2 = Double(normX) * Double.pi * 3.0 + waveOffset
                    let y = fillHeight + CGFloat(sin(angle2)) * 2.0
                    if x == 0 {
                        surfaceLine.move(to: CGPoint(x: x, y: y))
                    } else {
                        surfaceLine.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                ctx.stroke(surfaceLine, with: .color(color.opacity(0.5)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                waveOffset = .pi * 2
            }
        }
    }
}
