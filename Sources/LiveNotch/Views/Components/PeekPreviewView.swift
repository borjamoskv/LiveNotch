import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 👀 Peek Preview View
// ═══════════════════════════════════════════════════
// Mini music card for collapsed mode peek preview

struct PeekPreviewView: View {
    let trackName: String
    let artistName: String
    let albumArt: NSImage?
    let albumColor: Color
    let isPlaying: Bool
    let trackProgress: CGFloat
    let width: CGFloat
    let onPlayPause: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Space.lg) {
            if let art = albumArt {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(trackName)
                    .font(DS.Fonts.label)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(artistName)
                    .font(DS.Fonts.small)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
                
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(albumColor.opacity(0.6))
                            .frame(width: geo.size.width * trackProgress)
                    }
                }
                .frame(height: 3)
            }
            
            Spacer(minLength: 0)
            
            // Play/Pause button
            Button(action: {
                onPlayPause()
                HapticManager.shared.play(.toggle)
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: DS.Icons.body, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(DS.Colors.surfaceLight))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Space.lg)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .stroke(albumColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: DS.Shadow.lg, radius: 16, y: 8)
    }
}
