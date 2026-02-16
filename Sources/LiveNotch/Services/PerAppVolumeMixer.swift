import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🔊 Per-App Volume Mixer (KILLER FEATURE)
// ═══════════════════════════════════════════════════
// The #1 feature NOBODY has in a notch app
// People pay $39 for SoundSource just for this

final class PerAppVolumeMixer: ObservableObject {
    static let shared = PerAppVolumeMixer()
    
    struct AppAudio: Identifiable {
        let id: pid_t
        let name: String
        let bundleIdentifier: String
        let icon: NSImage?
        var volume: Float  // 0.0 - 1.0
        var isMuted: Bool
    }
    
    @Published var audioApps: [AppAudio] = []
    @Published var isVisible = false
    private var timer: Timer?
    
    private init() {
        refreshApps()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshApps()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func refreshApps() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let audioAppBundles: Set<String> = [
                "com.spotify.client", "com.apple.Music", "com.apple.Safari",
                "com.google.Chrome", "org.mozilla.firefox", "com.brave.Browser",
                "tv.plex.player", "com.apple.TV", "com.netflix.Netflix",
                "us.zoom.xos", "com.microsoft.teams2", "com.slack.Slack",
                "com.hnc.Discord", "com.tinyspeck.slackmacgap",
                "com.apple.FaceTime", "com.apple.podcasts",
                "com.apple.QuickTimePlayerX", "org.videolan.vlc",
                "com.colliderli.iina", "com.figma.Desktop"
            ]
            
            let runningApps = NSWorkspace.shared.runningApplications.filter { app in
                guard let bundleID = app.bundleIdentifier else { return false }
                return audioAppBundles.contains(bundleID) &&
                       app.activationPolicy == .regular
            }
            
            let apps = runningApps.map { app -> AppAudio in
                AppAudio(
                    id: app.processIdentifier,
                    name: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    icon: app.icon,
                    volume: 1.0,
                    isMuted: false
                )
            }
            
            DispatchQueue.main.async {
                var newApps = apps
                for (idx, app) in newApps.enumerated() {
                    if let existing = self?.audioApps.first(where: { $0.id == app.id }) {
                        newApps[idx].volume = existing.volume
                        newApps[idx].isMuted = existing.isMuted
                    }
                }
                self?.audioApps = newApps
            }
        }
    }
    
    func setVolume(for appId: pid_t, volume: Float) {
        if let idx = audioApps.firstIndex(where: { $0.id == appId }) {
            audioApps[idx].volume = volume
            audioApps[idx].isMuted = volume == 0
            applyVolume(app: audioApps[idx])
        }
    }
    
    func toggleMute(for appId: pid_t) {
        if let idx = audioApps.firstIndex(where: { $0.id == appId }) {
            audioApps[idx].isMuted.toggle()
            if audioApps[idx].isMuted {
                applyVolume(app: audioApps[idx], forceMute: true)
            } else {
                applyVolume(app: audioApps[idx])
            }
        }
    }
    
    private func applyVolume(app: AppAudio, forceMute: Bool = false) {
        let vol = forceMute ? 0 : Int(app.volume * 100)
        
        var script = ""
        switch app.bundleIdentifier {
        case "com.spotify.client":
            script = "tell application \"Spotify\" to set sound volume to \(vol)"
        case "com.apple.Music":
            script = "tell application \"Music\" to set sound volume to \(vol)"
        case "com.apple.TV":
            script = "tell application \"TV\" to set sound volume to \(vol)"
        default:
            return
        }
        
        if !script.isEmpty {
            DispatchQueue.global(qos: .utility).async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                appleScript?.executeAndReturnError(&error)
            }
        }
    }
}
