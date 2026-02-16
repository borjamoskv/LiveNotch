import os
import Foundation

// ═══════════════════════════════════════════════════
// MARK: - 📋 NotchLogger — Centralized Structured Logging
// ═══════════════════════════════════════════════════
//
// Replaces scattered NSLog/print calls with os.Logger backed logging.
// Each subsystem gets its own category for Console.app filtering.
//
// Usage:
//   private let log = NotchLog.make("NervousSystem")
//   log.debug("Mood changed to \(mood.rawValue)")
//   log.info("Flow state entered after \(minutes) minutes")
//   log.error("Failed to connect: \(error)")

/// Lightweight structured logger wrapping `os.Logger`.
///
/// Provides emoji-prefixed convenience methods and a consistent
/// subsystem (`LiveNotch`) so all logs are filterable in Console.app.
struct NotchLog {
    private let logger: Logger
    
    /// Create a logger for the given category (e.g. "NervousSystem", "MusicController").
    static func make(_ category: String) -> NotchLog {
        NotchLog(logger: Logger(subsystem: "LiveNotch", category: category))
    }
    
    // ── Log Levels ──
    
    /// 🔍 Debug: verbose, stripped in release builds
    func debug(_ message: String) {
        logger.debug("🔍 \(message, privacy: .public)")
    }
    
    /// ℹ️ Info: normal operational messages
    func info(_ message: String) {
        logger.info("ℹ️ \(message, privacy: .public)")
    }
    
    /// ⚠️ Warning: recoverable issues
    func warning(_ message: String) {
        logger.warning("⚠️ \(message, privacy: .public)")
    }
    
    /// ❌ Error: something failed
    func error(_ message: String) {
        logger.error("❌ \(message, privacy: .public)")
    }
    
    /// 🔥 Fault: critical / shouldn't happen
    func fault(_ message: String) {
        logger.fault("🔥 \(message, privacy: .public)")
    }
    
    // ── Convenience for lifecycle events ──
    
    /// Log initialization of a subsystem
    func started(_ label: String) {
        logger.info("✅ \(label, privacy: .public) ready")
    }
    
    /// Log a timed operation
    func timed(_ label: String, _ block: () throws -> Void) rethrows {
        let start = CFAbsoluteTimeGetCurrent()
        try block()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("⏱ \(label, privacy: .public): \(String(format: "%.1f", ms), privacy: .public)ms")
    }
}

// ═══════════════════════════════════════════════════
// MARK: - NSLog Migration Helper
// ═══════════════════════════════════════════════════
//
// For gradual migration: `NSLog` → `NotchLog.make("Category").info(...)`
// Files can adopt at their own pace. No runtime behavior change.
//
// Migration checklist:
//   1. Add `private let log = NotchLog.make("ClassName")`
//   2. Replace `NSLog("emoji Prefix: message")` → `log.info("message")`
//   3. Replace `print(...)` → `log.debug("...")`
