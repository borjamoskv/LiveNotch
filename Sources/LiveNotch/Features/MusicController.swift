import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Music Controller
// ═══════════════════════════════════════════════════
// Owns all music state, playback control, and Now Playing monitoring.
// Delegates art/color extraction to AlbumArtService.

@MainActor
final class MusicController: ObservableObject {
    private let log = NotchLog.make("MusicController")
    
    // ── Constants ──
    private enum Timing {
        static let pollingInterval: TimeInterval = 2.0
        static let interpolationInterval: TimeInterval = 1.0
        static let alertDuration: TimeInterval = 3.0
        static let playPauseDebounce: TimeInterval = 0.3
        static let trackChangeDebounce: TimeInterval = 0.5
    }

    // ── Now Playing State ──
    @Published var currentTrack = "Not Playing"
    @Published var currentArtist = ""
    @Published var isPlaying = false
    @Published var albumColor: Color = AlbumArtService.defaultPrimary
    @Published var albumColor2: Color = AlbumArtService.defaultSecondary
    @Published var trackProgress: Double = 0.0
    @Published var albumArtImage: NSImage? = nil
    @Published var trackDuration: Double = 0
    @Published var trackPosition: Double = 0
    
    // ── Visual Engines ──
    let quantumPalette = QuantumPaletteEngine()
    let rainEngine = RainPhysicsEngine()
    
    // ── Volume ──
    @Published var volume: Float = 50
    @Published var showVolumeSlider = false
    
    // ── Dynamic Island Alert ──
    @Published var songChangeAlert = false
    
    // ── Private ──
    private var npTimer: Timer?
    private var positionInterpolationTimer: Timer?
    private var songChangeTimer: Timer?
    private var lastArtUrl: String = ""
    private let artService = AlbumArtService()
    
    // ── Adapters ──
    private let adapters: [MusicAdapter] = [
        SpotifyAdapter(),
        AppleMusicAdapter(),
        YouTubeMusicController()
    ]
    private var activeAdapter: MusicAdapter?

    // ════════════════════════════════════════
    // MARK: - Lifecycle
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
        npTimer = Timer.scheduledTimer(withTimeInterval: Timing.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
        positionInterpolationTimer = Timer.scheduledTimer(withTimeInterval: Timing.interpolationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, self.trackDuration > 0 else { return }
                self.trackPosition = min(self.trackPosition + 1.0, self.trackDuration)
                self.trackProgress = min(1.0, self.trackPosition / self.trackDuration)
            }
        }
    }
    
    func updateNowPlaying() {
        let newActive = adapters.first { $0.isAvailable && ($0.getCurrentTrack()?.isPlaying ?? false) }
            ?? adapters.first { $0.isAvailable }
        
        self.activeAdapter = newActive
        
        guard let adapter = newActive, let track = adapter.getCurrentTrack() else {
            resetPlaybackState()
            return
        }
        
        let oldTrack = currentTrack
        let wasPlaying = isPlaying
        
        isPlaying = track.isPlaying
        NervousSystem.shared.isPlayingMusic = isPlaying
        currentTrack = track.title
        currentArtist = track.artist
        trackPosition = track.position
        trackDuration = track.duration
        
        if track.duration > 0 {
            trackProgress = min(1.0, track.position / track.duration)
        }
        
        if oldTrack != currentTrack {
            handleTrackChange(track: track, oldTrack: oldTrack)
        }
        
        if wasPlaying != isPlaying {
            HapticManager.shared.play(.toggle)
        }
    }
    
    private func resetPlaybackState() {
        currentTrack = "Not Playing"
        currentArtist = ""
        isPlaying = false
        NervousSystem.shared.isPlayingMusic = false
        albumArtImage = nil
        trackProgress = 0
    }
    
    private func handleTrackChange(track: Track, oldTrack: String) {
        if let img = track.artworkImage {
            applyArtwork(img)
        } else if let url = track.artworkURL {
            let urlStr = url.absoluteString
            if urlStr != lastArtUrl {
                lastArtUrl = urlStr
                fetchAndApplyArt(from: urlStr)
            }
        } else {
            fetchLastFMArt(artist: track.artist, title: track.title)
        }
        
        if !oldTrack.isEmpty && oldTrack != "Not Playing" {
            triggerSongChangeAlert()
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Album Art (via AlbumArtService)
    // ════════════════════════════════════════
    
    private func applyArtwork(_ img: NSImage) {
        withAnimation(DS.Anim.easeMedium) {
            self.albumArtImage = img
        }
        let colors = AlbumArtService.extractColors(from: img)
        withAnimation(DS.Anim.easeMedium) {
            albumColor = colors.primary
            albumColor2 = colors.secondary
        }
        quantumPalette.extractPalettes(from: img)
    }
    
    private func fetchAndApplyArt(from urlStr: String) {
        Task {
            guard let result = await artService.fetchArtAndColors(from: urlStr) else { return }
            withAnimation(DS.Anim.easeMedium) {
                albumArtImage = result.image
                albumColor = result.primaryColor
                albumColor2 = result.secondaryColor
            }
            quantumPalette.extractPalettes(from: result.image)
        }
    }
    
    private func fetchLastFMArt(artist: String, title: String) {
        guard !artist.isEmpty && !title.isEmpty else { return }
        Task {
            guard let img = await LastFMService.shared.fetchArtwork(artist: artist, track: title) else { return }
            applyArtwork(img)
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Playback Controls
    // ════════════════════════════════════════
    
    func togglePlayPause() {
        executeAdapterAction { $0.play() } fallback: {
            """
            if application "Spotify" is running then
                tell application "Spotify" to playpause
            else if application "Music" is running then
                tell application "Music" to playpause
            end if
            """
        }
        HapticManager.shared.play(.button)
        scheduleUpdate(after: Timing.playPauseDebounce)
    }
    
    func nextTrack() {
        executeAdapterAction { $0.next() } fallback: {
            """
            if application "Spotify" is running then
                tell application "Spotify" to next track
            else if application "Music" is running then
                tell application "Music" to next track
            end if
            """
        }
        HapticManager.shared.play(.button)
        scheduleUpdate(after: Timing.trackChangeDebounce)
    }
    
    func previousTrack() {
        executeAdapterAction { $0.previous() } fallback: {
            """
            if application "Spotify" is running then
                tell application "Spotify" to previous track
            else if application "Music" is running then
                tell application "Music" to back track
            end if
            """
        }
        HapticManager.shared.play(.button)
        scheduleUpdate(after: Timing.trackChangeDebounce)
    }
    
    func seekTo(position: Double) {
        if let adapter = activeAdapter {
            adapter.seek(to: position)
        } else {
            guard trackDuration > 0 else { return }
            let targetSeconds = position * trackDuration
            runAppleScript("""
            if application "Spotify" is running then
                tell application "Spotify" to set player position to \(targetSeconds)
            else if application "Music" is running then
                tell application "Music" to set player position to \(targetSeconds)
            end if
            """)
        }
        trackProgress = position
        HapticManager.shared.play(.button)
    }
    
    func openMusicApp() {
        if let source = activeAdapter?.source {
            let appName: String
            switch source {
            case .spotify: appName = "Spotify"
            case .appleMusic: appName = "Music"
            default: return
            }
            NSWorkspace.shared.launchApplication(appName)
        } else {
            runAppleScript("""
            if application "Spotify" is running then
                tell application "Spotify" to activate
            else if application "Music" is running then
                tell application "Music" to activate
            end if
            """)
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Volume
    // ════════════════════════════════════════
    
    func updateVolume() { volume = VolumeControl.getVolume() }
    func setVolume(_ value: Float) { volume = value; VolumeControl.setVolume(value) }
    func adjustVolume(by delta: Float) { setVolume(max(0, min(100, volume + delta))) }
    
    // ════════════════════════════════════════
    // MARK: - Dynamic Island Alert
    // ════════════════════════════════════════
    
    func triggerSongChangeAlert() {
        songChangeTimer?.invalidate()
        withAnimation(DS.Anim.springSoft) { songChangeAlert = true }
        songChangeTimer = Timer.scheduledTimer(withTimeInterval: Timing.alertDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(DS.Anim.springStd) { self?.songChangeAlert = false }
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
    // MARK: - Private Helpers
    // ════════════════════════════════════════
    
    /// Executes an action on the active adapter, or falls back to AppleScript.
    private func executeAdapterAction(_ action: (MusicAdapter) -> Void, fallback script: () -> String) {
        if let adapter = activeAdapter {
            action(adapter)
        } else {
            runAppleScript(script())
        }
    }
    
    /// Schedules a Now Playing update after a short delay.
    private func scheduleUpdate(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let script = NSAppleScript(source: source) else { return }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
}
