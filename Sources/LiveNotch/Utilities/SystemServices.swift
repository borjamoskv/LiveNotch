// ═══════════════════════════════════════════════════
// MARK: - 🏗️ SystemServices — Barrel File
// ═══════════════════════════════════════════════════
//
// This file previously contained 1,352 lines of mixed concerns.
// All services have been extracted into individual files under:
//
//   Sources/LiveNotch/Services/
//
// ├── VisionService.swift          — 👁️ OCR via Vision framework
// ├── HapticManager.swift          — 🔊 Haptic feedback
// ├── SystemMonitor.swift          — 📊 CPU/RAM + Memory Guardian
// ├── ClipboardManager.swift       — 📋 Clipboard history
// ├── CalendarService.swift        — 📅 EventKit integration
// ├── WeatherService.swift         — 🌤️ wttr.in weather
// ├── VolumeControl.swift          — 🔊 System volume
// ├── BluetoothMonitor.swift       — 🎧 AirPods/headphone detection
// ├── FullscreenDetector.swift     — 📺 Fullscreen app detection
// ├── SmartPolling.swift           — ⚡ Adaptive polling
// ├── BrainDumpManager.swift       — 🧠 Quick capture + AI categorization
// ├── MultiMonitorManager.swift    — 🖥️ Multi-monitor support
// ├── PerAppVolumeMixer.swift      — 🔊 Per-app volume control
// ├── SwipeGestureHandler.swift    — ✋ Swipe gesture detection
// ├── AppExclusionManager.swift    — 🚫 Per-app hide rules
// ├── ClipboardMonitorService.swift — 📋 Smart clipboard type detection
// └── MenuBarRedundancyManager.swift — 🔄 macOS menu bar icon management
//
// This file is kept as documentation. All types are now importable
// directly from their respective files in the Services/ directory.
// Swift Package Manager automatically includes all .swift files
// in the Sources directory.
