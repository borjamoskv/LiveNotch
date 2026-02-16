import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Music Controller
// ═══════════════════════════════════════════════════
// Extracted from NotchViewModel — owns all music state and playback control.
// Single Responsibility: Now Playing monitoring, album art, colors, controls.

@MainActor
final class MusicController: ObservableObject {
    
    // ── Now Playing State ──
    @Published var currentTrack = "Not Playing"
    @Published var currentArtist = ""
    @Published var isPlaying = false
    @Published var albumColor: Color = Color(red: 0.35, green: 0.65, blue: 1.0)
    @Published var albumColor2: Color = Color(red: 0.65, green: 0.35, blue: 1.0)
    @Published var trackProgress: Double = 0.0
    @Published var albumArtImage: NSImage? = nil
    @Published var trackDuration: Double = 0
    @Published var trackPosition: Double = 0
    
    // ── Volume ──
    @Published var volume: Float = 50
    @Published var showVolumeSlider = false
    
    // ── Dynamic Island Alert ──
    @Published var songChangeAlert = false
    
    // ── Exclusive Audio Mode ──
    // When enabled, only one audio source can play at a time.
    // Starting playback in one app will pause the other.
    @Published var exclusiveAudioMode: Bool = true
    private var activeAudioSource: AudioSource = .none
    
    enum AudioSource: String {
        case spotify = "Spotify"
        case music = "Music"
        case none = "None"
    }
    
    // ── Private ──
    private var npTimer: Timer?
    private var positionInterpolationTimer: Timer?
    private var songChangeTimer: Timer?
    private var lastPositionUpdate = Date()
    private var lastArtUrl: String = ""
    
    // ── Adapters ──
    private let adapters: [MusicAdapter] = [
        SpotifyAdapter(),
        AppleMusicAdapter(),
        YouTubeMusicController()
    ]
    private var activeAdapter: MusicAdapter?

    // ════════════════════════════════════════
    // MARK: - Init
    // ════════════════════════════════════════
    
    init() {
        startNowPlayingMonitor()
        updateVolume()
    }
    
    deinit {
        npTimer?.invalidate()
        positionInterpolationTimer?.invalidate()
        songChangeTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Now Playing Monitor
    // ════════════════════════════════════════
    
    func startNowPlayingMonitor() {
        updateNowPlaying()
        npTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
        // Local interpolation: advance position smoothly between polls
        positionInterpolationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, self.trackDuration > 0 else { return }
                self.trackPosition = min(self.trackPosition + 1.0, self.trackDuration)
                self.trackProgress = min(1.0, self.trackPosition / self.trackDuration)
            }
        }
    }
    
    func updateNowPlaying() {
        // 1. Find active adapter
        let newActive = adapters.first { $0.isAvailable && ($0.getCurrentTrack()?.isPlaying ?? false) } 
            ?? adapters.first { $0.isAvailable }
        
        self.activeAdapter = newActive
        
        guard let adapter = newActive, let track = adapter.getCurrentTrack() else {
            // Fallback to legacy AppleScript for Browser/Others if no adapter is available
            runLegacyAppleScriptUpdate()
            return
        }
        
        // 2. Update state from adapter
        let oldTrack = self.currentTrack
        let wasPlaying = self.isPlaying
        
        self.isPlaying = track.isPlaying
        NervousSystem.shared.isPlayingMusic = self.isPlaying
        self.currentTrack = track.title
        self.currentArtist = track.artist
        self.trackPosition = track.position
        self.trackDuration = track.duration
        self.lastPositionUpdate = Date()
        
        if track.duration > 0 {
            self.trackProgress = min(1.0, track.position / track.duration)
        }
        
        // 3. Album Art
        if oldTrack != self.currentTrack {
            if let img = track.artworkImage {
                withAnimation(DS.Anim.easeMedium) {
                    self.albumArtImage = img
                }
                // Color extraction (simplified or reuse existing)
                // extractColorFromImage(img) 
            } else if let url = track.artworkURL {
                let urlStr = url.absoluteString
                if urlStr != self.lastArtUrl {
                    self.lastArtUrl = urlStr
                    self.extractColor(from: urlStr)
                    self.loadAlbumArt(from: urlStr)
                }
            } else {
                // FALLBACK: Last.fm
                let artistFallback = track.artist
                let titleFallback = track.title
                if !artistFallback.isEmpty && !titleFallback.isEmpty {
                    Task {
                        if let lastFMArt = await LastFMService.shared.fetchArtwork(artist: artistFallback, track: titleFallback) {
                            withAnimation(DS.Anim.easeMedium) {
                                self.albumArtImage = lastFMArt
                                self.extractColorFromImage(lastFMArt)
                            }
                        }
                    }
                }
            }
            
            if oldTrack != "Not Playing" && oldTrack != "" {
                self.triggerSongChangeAlert()
            }
        }
        
        if wasPlaying != self.isPlaying {
            HapticManager.shared.play(.toggle)
        }
    }
    
    private func runLegacyAppleScriptUpdate() {
        let script = """
        if application "Spotify" is running then
            return "NONE" -- Handled by adapter
        else if application "Music" is running then
            return "NONE" -- Handled by adapter
        else
            -- Check for browsers or other things not yet adapted
            -- Add browser detection here if needed
            return "NONE"
        end if
        """
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let as_ = NSAppleScript(source: script) else { return }
            var err: NSDictionary?
            let out = as_.executeAndReturnError(&err)
            
            Task { @MainActor [weak self] in
                guard let self = self, let r = out.stringValue else { return }
                let p = r.split(separator: "|", omittingEmptySubsequences: false)
                
                // The legacy script is now simplified to always return "NONE" if Spotify/Music are running.
                // If other apps were to be added here, this logic would need to be expanded.
                if r == "NONE" {
                    self.currentTrack = "Not Playing"
                    self.currentArtist = ""
                    self.isPlaying = false
                    NervousSystem.shared.isPlayingMusic = false
                    self.albumArtImage = nil
                    self.trackProgress = 0
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Album Art & Color Extraction
    // ════════════════════════════════════════
    
    func loadAlbumArt(from urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let d = try? Data(contentsOf: url), let img = NSImage(data: d) else { return }
            Task { @MainActor [weak self] in
                withAnimation(DS.Anim.easeMedium) {
                    self?.albumArtImage = img
                }
            }
        }
    }
    
    func extractColor(from urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let d = try? Data(contentsOf: url), let img = NSImage(data: d) else { return }
            self?.extractColorFromImage(img)
        }
    }
    
    private func extractColorFromImage(_ img: NSImage) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let t = img.tiffRepresentation, let bmp = NSBitmapImageRep(data: t) else { return }
            
            // Sample center region for dominant color
            var rT: CGFloat = 0, gT: CGFloat = 0, bT: CGFloat = 0, c: CGFloat = 0
            let sampleSize = 12
            for i in 0..<sampleSize {
                for j in 0..<sampleSize {
                    let x = bmp.pixelsWide / 4 + i * (bmp.pixelsWide / (sampleSize * 2))
                    let y = bmp.pixelsHigh / 4 + j * (bmp.pixelsHigh / (sampleSize * 2))
                    if let col = bmp.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                        rT += col.redComponent
                        gT += col.greenComponent
                        bT += col.blueComponent
                        c += 1
                    }
                }
            }
            
            guard c > 0 else { return }
            let r = rT / c, g = gT / c, b = bT / c
            let maxC = max(r, g, b)
            let sat = maxC > 0 ? (maxC - min(r, g, b)) / maxC : 0
            
            Task { @MainActor [weak self] in
                withAnimation(DS.Anim.easeMedium) {
                    if sat > 0.10 {
                        self?.albumColor = Color(red: min(1, r * 1.5), green: min(1, g * 1.5), blue: min(1, b * 1.5))
                        self?.albumColor2 = Color(red: min(1, b * 1.2), green: min(1, r * 1.2), blue: min(1, g * 1.2))
                    } else {
                        self?.albumColor = Color(red: 0.4, green: 0.75, blue: 1.0)
                        self?.albumColor2 = Color(red: 0.75, green: 0.4, blue: 1.0)
                    }
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Playback Controls
    // ════════════════════════════════════════
    
    func togglePlayPause() {
        if let adapter = activeAdapter {
            adapter.play() // Or toggle if adapter supports it. Most play() toggle in these implementations.
        } else {
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to playpause
            else if application "Music" is running then
                tell application "Music" to playpause
            end if
            """
            runAppleScript(script)
        }
        HapticManager.shared.play(.button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func nextTrack() {
        if let adapter = activeAdapter {
            adapter.next()
        } else {
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to next track
            else if application "Music" is running then
                tell application "Music" to next track
            end if
            """
            runAppleScript(script)
        }
        HapticManager.shared.play(.button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func previousTrack() {
        if let adapter = activeAdapter {
            adapter.previous()
        } else {
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to previous track
            else if application "Music" is running then
                tell application "Music" to back track
            end if
            """
            runAppleScript(script)
        }
        HapticManager.shared.play(.button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    func seekTo(position: Double) {
        if let adapter = activeAdapter {
            adapter.seek(to: position)
        } else {
            guard trackDuration > 0 else { return }
            let targetSeconds = position * trackDuration
            let script = """
            if application "Spotify" is running then
                tell application "Spotify" to set player position to \(targetSeconds)
            else if application "Music" is running then
                tell application "Music" to set player position to \(targetSeconds)
            end if
            """
            runAppleScript(script)
        }
        trackProgress = position
        HapticManager.shared.play(.button)
    }
    
    func openMusicApp() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to activate
        else if application "Music" is running then
            tell application "Music" to activate
        end if
        """
        runAppleScript(script)
    }
    
    // ════════════════════════════════════════
    // MARK: - Volume
    // ════════════════════════════════════════
    
    func updateVolume() {
        volume = VolumeControl.getVolume()
    }
    
    func setVolume(_ value: Float) {
        volume = value
        VolumeControl.setVolume(value)
    }
    
    func adjustVolume(by delta: Float) {
        let newVol = max(0, min(100, volume + delta))
        setVolume(newVol)
    }
    
    // ════════════════════════════════════════
    // MARK: - Dynamic Island Alert
    // ════════════════════════════════════════
    
    func triggerSongChangeAlert() {
        songChangeTimer?.invalidate()
        withAnimation(DS.Anim.springSoft) {
            songChangeAlert = true
        }
        songChangeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(DS.Anim.springStd) {
                    self?.songChangeAlert = false
                }
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Computed Properties
    // ════════════════════════════════════════
    
    var trackTimeDisplay: String {
        let pos = max(0, Int(trackPosition))
        let dur = max(0, Int(trackDuration))
        return String(format: "%d:%02d / %d:%02d", pos / 60, pos % 60, dur / 60, dur % 60)
    }
    
    var elapsedTimeString: String {
        let pos = max(0, Int(trackPosition))
        return String(format: "%d:%02d", pos / 60, pos % 60)
    }
    
    var volumeIcon: String {
        switch volume {
        case 0: return "speaker.slash.fill"
        case 1..<33: return "speaker.wave.1.fill"
        case 33..<66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Exclusive Audio
    // ════════════════════════════════════════
    
    /// Detects which audio source is currently playing and pauses any others.
    /// Now supports: Spotify, Music, Chrome, Safari, Arc, Brave, YouTube (via browser).
    private func enforceExclusiveAudio() {
        // Detect which source is active now using AppleScript (fast check)
        // We check for "playing" state in media apps and browsers.
        let detectScript = """
        set sources to {}
        
        -- Native Apps
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then set end of sources to "Spotify"
            end tell
        end if
        if application "Music" is running then
            tell application "Music"
                if player state is playing then set end of sources to "Music"
            end tell
        end if
        
        -- Browsers (Chrome/Arc/Brave/Safari check)
        -- Note: Browser checking is heuristic based on window titles or JS if possible, 
        -- but for high-level exclusivity we assume if native music starts, we pause native music.
        -- Controlling browser tabs is tricky without extensions, so we prioritize Native > Native.
        -- For Browser > Native, we can monitor if a browser is OUTPUTTING audio (via CoreAudio if added later).
        
        -- For now: Strict enforcement between Spotify <-> Music to prevent double playback.
        -- Browser support requires deeper accessibility access which might be slow for polling.
        
        return (sources as text)
        """
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let script = NSAppleScript(source: detectScript) else { return }
            var err: NSDictionary?
            let result = script.executeAndReturnError(&err)
            guard let sources = result.stringValue else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let spotifyPlaying = sources.contains("Spotify")
                let musicPlaying = sources.contains("Music")
                
                // ⚔️ Conflict Resolution: Highlander Mode (There can be only one)
                if spotifyPlaying && musicPlaying {
                    if self.activeAudioSource == .spotify {
                        // Spotify was master, kill Music
                        self.pauseApp(.music)
                    } else if self.activeAudioSource == .music {
                        // Music was master, kill Spotify
                        self.pauseApp(.spotify)
                    } else {
                        // Default priority: Spotify wins
                        self.activeAudioSource = .spotify
                        self.pauseApp(.music)
                    }
                } else if spotifyPlaying {
                    self.activeAudioSource = .spotify
                    self.pauseBrowsers() // 🛑 Pause YouTube/etc
                } else if musicPlaying {
                    self.activeAudioSource = .music
                    self.pauseBrowsers() // 🛑 Pause YouTube/etc
                } else {
                    self.activeAudioSource = .none
                }
            }
        }
    }
    
    /// Pause a specific audio application.
    private func pauseApp(_ source: AudioSource) {
        let appName = source.rawValue
        // Fade out before pause if possible (requires more complex script), currently instant pause.
        let script = "tell application \"\(appName)\" to pause"
        NSLog("🎵 Exclusive Audio: Auto-pausing \(appName) to allow focus.")
        runAppleScript(script)
    }
    
    // ════════════════════════════════════════
    // MARK: - Browser Control
    // ════════════════════════════════════════
    
    func pauseBrowsers() {
        // Since browsers don't have standard "pause" AE commands, we simulate play/pause media key
        // or try specific JS injection for known heavy hitters (a bit hacky but works for YouTube often).
        //
        // NOTE: The most reliable way for browsers without extensions is simulating "Media Play/Pause" key
        // but that toggles *everything*. so we have to be careful.
        //
        // Alternative: Use "execute javascript" in active tab if supported.
        
        let script = """
        -- Chrome / Brave / Arc
        if application "Google Chrome" is running then
            tell application "Google Chrome"
                execute front window's active tab javascript "document.querySelectorAll('video, audio').forEach(e => e.pause())"
            end tell
        end if
        
        if application "Brave Browser" is running then
            tell application "Brave Browser"
                execute front window's active tab javascript "document.querySelectorAll('video, audio').forEach(e => e.pause())"
            end tell
        end if
        
        if application "Arc" is running then
            tell application "Arc"
                execute front window's active tab javascript "document.querySelectorAll('video, audio').forEach(e => e.pause())"
            end tell
        end if
        
        if application "Safari" is running then
            tell application "Safari"
                do JavaScript "document.querySelectorAll('video, audio').forEach(e => e.pause())" in current tab of front window
            end tell
        end if
        """
        runAppleScript(script)
    }
    
    // ════════════════════════════════════════
    // MARK: - Helpers
    // ════════════════════════════════════════
    
    private func parseLocaleDouble(_ str: String) -> Double? {
        if let v = Double(str) { return v }
        let normalized = str.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let script = NSAppleScript(source: source) else { return }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
}
