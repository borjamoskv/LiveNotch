import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎤 Live Lyrics Engine
// ═══════════════════════════════════════════════════
// Fetches synced lyrics from LRCLIB API, parses LRC timestamps,
// and auto-scrolls to the current line based on playback position.
// Works with Spotify, Apple Music, and any player via MusicController.

@MainActor
final class LiveLyricsEngine: ObservableObject {
    static let shared = LiveLyricsEngine()
    
    // ── Published State ──
    @Published var lyrics: [LyricLine] = []
    @Published var currentLineIndex: Int = 0
    @Published var isLoading = false
    @Published var hasLyrics = false
    @Published var errorMessage: String? = nil
    
    // ── Tracking ──
    private var currentTrackKey = ""  // "artist|title"
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let lrcCache = NSCache<NSString, CachedLyrics>()
    
    private init() {}
    
    // ════════════════════════════════════════
    // MARK: - Wire to MusicController
    // ════════════════════════════════════════
    
    func wireToMusic(_ music: MusicController) {
        // Watch for track changes
        music.$currentTrack
            .combineLatest(music.$currentArtist)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] track, artist in
                guard let self = self else { return }
                let key = "\(artist)|\(track)"
                if key != self.currentTrackKey && !track.isEmpty && track != "Not Playing" {
                    self.currentTrackKey = key
                    Task { await self.fetchLyrics(artist: artist, title: track) }
                }
            }
            .store(in: &cancellables)
        
        // Sync position every 100ms
        startSyncTimer(music: music)
    }
    
    private func startSyncTimer(music: MusicController) {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak music] _ in
            Task { @MainActor in
                guard let self = self, let music = music else { return }
                self.updateCurrentLine(position: music.trackPosition)
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - LRCLIB Fetch
    // ════════════════════════════════════════
    
    func fetchLyrics(artist: String, title: String) async {
        // Check cache first
        let cacheKey = "\(artist)|\(title)" as NSString
        if let cached = lrcCache.object(forKey: cacheKey) {
            self.lyrics = cached.lines
            self.hasLyrics = !cached.lines.isEmpty
            self.currentLineIndex = 0
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Clean the title — remove " - Single", "(feat. ...)" etc.
        let cleanTitle = title
            .replacingOccurrences(of: #"\s*\(feat\..*?\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*-\s*Single$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        let cleanArtist = artist
            .trimmingCharacters(in: .whitespaces)
        
        guard let artistEncoded = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let titleEncoded = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            isLoading = false
            return
        }
        
        let urlString = "https://lrclib.net/api/get?artist_name=\(artistEncoded)&track_name=\(titleEncoded)"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("LiveNotch/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                self.lyrics = []
                self.hasLyrics = false
                self.isLoading = false
                return
            }
            
            let lrcResponse = try JSONDecoder().decode(LRCLibResponse.self, from: data)
            
            // Prefer synced lyrics, fall back to plain
            if let syncedLRC = lrcResponse.syncedLyrics, !syncedLRC.isEmpty {
                let parsed = parseLRC(syncedLRC)
                self.lyrics = parsed
                self.hasLyrics = !parsed.isEmpty
                self.lrcCache.setObject(CachedLyrics(parsed), forKey: cacheKey)
            } else if let plainLyrics = lrcResponse.plainLyrics, !plainLyrics.isEmpty {
                let lines = plainLyrics.components(separatedBy: "\n")
                    .enumerated()
                    .map { LyricLine(timestamp: Double($0.offset) * 3.0, text: $0.element) }
                self.lyrics = lines
                self.hasLyrics = !lines.isEmpty
            } else {
                self.lyrics = []
                self.hasLyrics = false
            }
            
            self.currentLineIndex = 0
            
        } catch {
            self.errorMessage = "Lyrics not found"
            self.lyrics = []
            self.hasLyrics = false
        }
        
        isLoading = false
    }
    
    // ════════════════════════════════════════
    // MARK: - LRC Parser
    // ════════════════════════════════════════
    
    /// Parse LRC format: [mm:ss.xx] Text
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        var lines: [LyricLine] = []
        
        for line in lrc.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range) {
                let min = (line as NSString).substring(with: match.range(at: 1))
                let sec = (line as NSString).substring(with: match.range(at: 2))
                let ms  = (line as NSString).substring(with: match.range(at: 3))
                let text = (line as NSString).substring(with: match.range(at: 4))
                    .trimmingCharacters(in: .whitespaces)
                
                let minutes = Double(min) ?? 0
                let seconds = Double(sec) ?? 0
                let millis: Double
                if ms.count == 2 {
                    millis = (Double(ms) ?? 0) / 100.0
                } else {
                    millis = (Double(ms) ?? 0) / 1000.0
                }
                
                let timestamp = minutes * 60.0 + seconds + millis
                
                if !text.isEmpty {
                    lines.append(LyricLine(timestamp: timestamp, text: text))
                }
            }
        }
        
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
    
    // ════════════════════════════════════════
    // MARK: - Sync Position
    // ════════════════════════════════════════
    
    private func updateCurrentLine(position: Double) {
        guard !lyrics.isEmpty else { return }
        
        // Find the last line whose timestamp <= current position
        var newIndex = 0
        for (i, line) in lyrics.enumerated() {
            if line.timestamp <= position {
                newIndex = i
            } else {
                break
            }
        }
        
        if newIndex != currentLineIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentLineIndex = newIndex
            }
        }
    }
    
    // ════════════════════════════════════════
    // MARK: - Cleanup
    // ════════════════════════════════════════
    
    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        cancellables.removeAll()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Data Models
// ═══════════════════════════════════════════════════

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Double  // seconds from start
    let text: String
}

// NSCache requires class values — wrap [LyricLine] in a class
final class CachedLyrics: NSObject {
    let lines: [LyricLine]
    init(_ lines: [LyricLine]) { self.lines = lines }
}

/// LRCLIB API response model
struct LRCLibResponse: Codable {
    let id: Int?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
}
