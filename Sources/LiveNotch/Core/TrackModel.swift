import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Track Model — Unified Music Representation
// ═══════════════════════════════════════════════════
// All music adapters normalize to this single model.
// The Notch only renders Track — never knows the source.

struct Track: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var artist: String
    var album: String
    var artworkImage: NSImage?
    var artworkURL: URL?
    var isPlaying: Bool
    var position: TimeInterval      // Current playback position
    var duration: TimeInterval       // Total track duration
    var source: TrackSource
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return position / duration
    }
    
    var hasArtwork: Bool { artworkImage != nil || artworkURL != nil }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
    }
}

enum TrackSource: String {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case browser = "Browser"
    case tidal = "TIDAL"
    case youtubeMusic = "YouTube Music"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .spotify: return "s.circle.fill"
        case .appleMusic: return "music.note"
        case .browser: return "play.rectangle.fill"
        case .tidal: return "t.circle.fill"
        case .youtubeMusic: return "play.square.fill"
        case .unknown: return "music.note"
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🔌 Music Adapter Protocol
// ═══════════════════════════════════════════════════
// Each source implements this protocol.
// The MusicController queries all adapters and uses
// the one that's currently active.

protocol MusicAdapter {
    var source: TrackSource { get }
    var isAvailable: Bool { get }
    
    func getCurrentTrack() -> Track?
    func play()
    func pause()
    func next()
    func previous()
    func seek(to position: Double)  // 0.0 - 1.0
    func setVolume(_ volume: Float) // 0.0 - 1.0
}

// ═══════════════════════════════════════════════════
// MARK: - 🎧 Spotify Adapter (AppleScript)
// ═══════════════════════════════════════════════════

struct SpotifyAdapter: MusicAdapter {
    let source: TrackSource = .spotify
    
    var isAvailable: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }
    
    func getCurrentTrack() -> Track? {
        guard isAvailable else { return nil }
        
        let script = """
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackPos to player position
                set trackDur to duration of current track
                return trackName & "|" & trackArtist & "|" & trackAlbum & "|" & (trackPos as string) & "|" & (trackDur as string)
            end if
        end tell
        """
        
        guard let result = runAppleScript(script) else { return nil }
        let parts = result.components(separatedBy: "|")
        guard parts.count >= 5 else { return nil }
        
        return Track(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: true,
            position: Double(parts[3]) ?? 0,
            duration: (Double(parts[4]) ?? 0) / 1000, // Spotify returns ms
            source: .spotify
        )
    }
    
    func play() { runAppleScript("tell application \"Spotify\" to play") }
    func pause() { runAppleScript("tell application \"Spotify\" to pause") }
    func next() { runAppleScript("tell application \"Spotify\" to next track") }
    func previous() { runAppleScript("tell application \"Spotify\" to previous track") }
    func seek(to position: Double) {
        // Calculate seconds from fraction
    }
    func setVolume(_ volume: Float) {
        let v = Int(volume * 100)
        runAppleScript("tell application \"Spotify\" to set sound volume to \(v)")
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Apple Music Adapter (AppleScript)
// ═══════════════════════════════════════════════════

struct AppleMusicAdapter: MusicAdapter {
    let source: TrackSource = .appleMusic
    
    var isAvailable: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
    }
    
    func getCurrentTrack() -> Track? {
        guard isAvailable else { return nil }
        
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackPos to player position
                set trackDur to duration of current track
                return trackName & "|" & trackArtist & "|" & trackAlbum & "|" & (trackPos as string) & "|" & (trackDur as string)
            end if
        end tell
        """
        
        guard let result = runAppleScript(script) else { return nil }
        let parts = result.components(separatedBy: "|")
        guard parts.count >= 5 else { return nil }
        
        return Track(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: true,
            position: Double(parts[3]) ?? 0,
            duration: Double(parts[4]) ?? 0,
            source: .appleMusic
        )
    }
    
    func play() { runAppleScript("tell application \"Music\" to play") }
    func pause() { runAppleScript("tell application \"Music\" to pause") }
    func next() { runAppleScript("tell application \"Music\" to next track") }
    func previous() { runAppleScript("tell application \"Music\" to previous track") }
    func seek(to position: Double) {}
    func setVolume(_ volume: Float) {
        let v = Int(volume * 100)
        runAppleScript("tell application \"Music\" to set sound volume to \(v)")
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }
}
