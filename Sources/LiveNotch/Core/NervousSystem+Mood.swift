import Foundation

extension NervousSystem {
    // ── Mood States ──
    enum Mood: String, CaseIterable {
        case idle       // ⚪ Nothing happening — barely visible
        case focus      // 🟢 Deep work — same app >3min, low distractions
        case active     // 🔵 Normal work — switching apps, moderate activity
        case stressed   // 🔴 System under load — high CPU, many switches
        case music      // 🎵 Music playing — album color dominates
        case meeting    // 🟡 Video call active — Zoom/Meet/Teams/FaceTime
        case creative   // 🟣 Creative apps — Photoshop, Ableton, etc.
        case coding     // 🔵 Coding apps — generic coding state
        case dreaming   // 🟣 Late night / inactive state
    }
}
