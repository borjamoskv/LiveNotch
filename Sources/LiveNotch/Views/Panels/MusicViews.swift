import SwiftUI
import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Music Views — Compact & Premium
// ═══════════════════════════════════════════════════

extension NotchView {
    
    // ═══════════════════════════════════════
    // MARK: - Music Section (Expanded) — ~305px width
    // ═══════════════════════════════════════
    
    func musicSection() -> some View {
        VStack(spacing: 8) {
            // ── Album art + track info — compact row ──
            HStack(spacing: 12) {
                // Album art with premium bio-luminescence + reflection
                VStack(spacing: 0) {
                    ZStack {
                        if let art = viewModel.albumArtImage {
                            // Ambient aura (ALCOVE)
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 54, height: 54)
                                .blur(radius: 20)
                                .opacity(0.4)
                                .scaleEffect(1.5)
                            
                            // Main album art
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                                .scaleEffect(viewModel.isPlaying ? 1.03 : 1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true), value: viewModel.isPlaying)
                                .id(viewModel.currentTrack)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16, weight: .ultraLight))
                                        .foregroundColor(DS.Colors.textGhost)
                                )
                        }
                    }
                    // Mirror reflection below album art
                    if let art = viewModel.albumArtImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .scaleEffect(x: 1, y: -1)
                            .mask(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blur(radius: 1)
                            .offset(y: -2)
                    }
                }
                
                // Track info + progress
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentTrack.uppercased())
                        .font(DS.Fonts.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .tracking(0.8)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(viewModel.currentArtist)
                            .font(DS.Fonts.small)
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                        
                        // Source Icon
                        Image(systemName: sourceIcon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DS.Colors.textGhost)
                    }
                    
                    Spacer().frame(height: 4)
                    
                    // Progress bar — Technical/Industrial
                    InteractiveProgressBar(
                        progress: viewModel.trackProgress,
                        color: viewModel.albumColor,
                        color2: viewModel.albumColor2,
                        onSeek: { position in
                            viewModel.seekTo(position: position)
                        }
                    )
                    
                    // Time — Monospace is essential for ALCOVE
                    Text(viewModel.trackTimeDisplay)
                        .font(DS.Fonts.microMono)
                        .foregroundColor(DS.Colors.textDim)
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // ── Controls — Minimal Industrial ──
            HStack(spacing: 24) {
                Button(action: { viewModel.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: { viewModel.togglePlayPause() }) {
                    ZStack {
                        // Base circle with gradient fill
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        viewModel.isPlaying ? viewModel.albumColor.opacity(0.08) : Color.white.opacity(0.06),
                                        Color.white.opacity(0.02)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 22
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [
                                            viewModel.isPlaying ? viewModel.albumColor.opacity(0.3) : .white.opacity(0.15),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                            )
                        
                        // The "Pulse" ring — actually visible now
                        if viewModel.isPlaying {
                            PulseRingView(color: viewModel.albumColor)
                        }
                        
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(viewModel.isPlaying ? viewModel.albumColor : .white)
                            .shadow(color: viewModel.isPlaying ? viewModel.albumColor.opacity(0.6) : .clear, radius: 10)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: { viewModel.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.top, 4)           // ── Inline volume + waveform ──
            HStack(spacing: 6) {
                Image(systemName: volumeIcon)
                    .font(DS.Fonts.micro)
                    .foregroundColor(.white.opacity(0.25))
                
                NotchVolumeSlider(
                    volume: $viewModel.volume,
                    color: self.viewModel.albumColor,
                    onChanged: { vol in self.viewModel.setVolume(vol) }
                )
                
                // Live Audio Visualizer
                NotchMiniWaveform(color: self.viewModel.albumColor)
                    .frame(width: 24, height: 12)
            }
            .padding(.horizontal, 6)
        }
        .padding(.top, 4)
    }
    
    // ── Multimedia Source Detection ──
    private var sourceIcon: String {
        let track = viewModel.currentTrack.lowercased()
        let artist = viewModel.currentArtist.lowercased()
        
        if track.contains("spotify") || artist.contains("spotify") { return "s.circle.fill" }
        if track.contains("youtube") || track.contains("safari") || track.contains("chrome") { return "play.rectangle.fill" }
        if track.contains("music") || artist.contains("apple") { return "apple.logo" }
        if track.contains("tidal") { return "t.circle.fill" }
        return "music.note"
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎚️ Interactive Progress Bar (Seek on Click)
// ═══════════════════════════════════════════════════

struct InteractiveProgressBar: View {
    let progress: Double
    let color: Color
    let color2: Color
    var onSeek: ((Double) -> Void)?
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var displayProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.06))
                
                // Filled progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color2.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * displayProgress))
                
                // Always-visible glow dot at progress head
                Circle()
                    .fill(Color.white)
                    .frame(width: isHovered || isDragging ? 8 : 5, height: isHovered || isDragging ? 8 : 5)
                    .shadow(color: color.opacity(0.7), radius: isHovered ? 5 : 3)
                    .shadow(color: color.opacity(0.3), radius: 8)
                    .offset(x: max(0, min(geo.size.width * displayProgress - (isHovered ? 4 : 2.5), geo.size.width - (isHovered ? 8 : 5))))
            }
            .frame(height: isHovered || isDragging ? 5 : 3)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
            .contentShape(Rectangle().inset(by: -8))
            .onHover { h in isHovered = h }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragProgress = max(0, min(1, value.location.x / geo.size.width))
                    }
                    .onEnded { value in
                        let pos = max(0, min(1, value.location.x / geo.size.width))
                        onSeek?(pos)
                        isDragging = false
                        HapticManager.shared.play(.button)
                    }
            )
        }
        .frame(height: 5)
        .clipShape(Capsule())
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 💫 Pulse Ring View (Play Button Heartbeat)
// ═══════════════════════════════════════════════════

struct PulseRingView: View {
    let color: Color
    @State private var animating = false
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .scaleEffect(animating ? 1.35 : 1.0)
                .opacity(animating ? 0 : 0.6)
            
            // Inner subtle glow
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 1)
                .frame(width: 44, height: 44)
                .scaleEffect(animating ? 1.15 : 1.0)
                .opacity(animating ? 0 : 0.4)
        }
        .onAppear {
            withAnimation(DS.Spring.liquid) {
                animating = true
            }
        }
    }
}
