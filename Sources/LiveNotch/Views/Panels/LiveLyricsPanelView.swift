import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎤 Live Lyrics Panel View
// ═══════════════════════════════════════════════════
// Auto-scrolling synced lyrics display for the expanded notch.
// Shows 5 lines: 2 past, current (highlighted), 2 future.

struct LiveLyricsPanelView: View {
    @ObservedObject var lyrics: LiveLyricsEngine
    @ObservedObject var music: MusicController
    
    var body: some View {
        VStack(spacing: 4) {
            // ── Header ──
            HStack {
                Image(systemName: "music.note.list")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.accentBlue)
                
                Text("LYRICS")
                    .font(DS.Fonts.microMono)
                    .foregroundStyle(DS.Colors.textTertiary)
                
                Spacer()
                
                if lyrics.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            
            if lyrics.hasLyrics {
                // ── Lyrics Display ──
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(lyrics.lyrics.enumerated()), id: \.element.id) { index, line in
                                Text(line.text)
                                    .font(index == lyrics.currentLineIndex ? DS.Fonts.captionBold : DS.Fonts.caption)
                                    .foregroundStyle(
                                        index == lyrics.currentLineIndex
                                            ? Color.white
                                            : index < lyrics.currentLineIndex
                                                ? DS.Colors.textTertiary
                                                : DS.Colors.textSecondary
                                    )
                                    .opacity(opacityFor(index: index))
                                    .scaleEffect(index == lyrics.currentLineIndex ? 1.05 : 1.0)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .id(line.id)
                                    .animation(DS.Spring.island, value: lyrics.currentLineIndex)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 80)
                    .onChange(of: lyrics.currentLineIndex) { _, newIndex in
                        if newIndex < lyrics.lyrics.count {
                            withAnimation(DS.Spring.island) {
                                proxy.scrollTo(lyrics.lyrics[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            } else if let error = lyrics.errorMessage {
                Text(error)
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
            } else if music.isPlaying {
                Text("♫ No lyrics found")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                Text("Play a song to see lyrics")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(DS.Colors.bgDark.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.strokeFaint, lineWidth: 0.5)
        )
    }
    
    // Fade out lines further from current
    private func opacityFor(index: Int) -> Double {
        let distance = abs(index - lyrics.currentLineIndex)
        switch distance {
        case 0: return 1.0
        case 1: return 0.7
        case 2: return 0.4
        default: return 0.2
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Compact Lyrics Wing
// ═══════════════════════════════════════════════════

struct LyricsWingView: View {
    @ObservedObject var lyrics: LiveLyricsEngine
    
    var body: some View {
        if lyrics.hasLyrics, lyrics.currentLineIndex < lyrics.lyrics.count {
            Text(lyrics.lyrics[lyrics.currentLineIndex].text)
                .font(DS.Fonts.micro)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 100)
                .animation(DS.Spring.soft, value: lyrics.currentLineIndex)
        }
    }
}
