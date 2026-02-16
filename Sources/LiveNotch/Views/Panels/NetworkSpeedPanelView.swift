import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🌐 Network Speed Panel View
// ═══════════════════════════════════════════════════
// Compact ↑/↓ speed display for the expanded notch panel.

struct NetworkSpeedPanelView: View {
    @ObservedObject var monitor: NetworkSpeedMonitor
    
    var body: some View {
        VStack(spacing: 6) {
            // ── Header ──
            HStack {
                Image(systemName: monitor.isConnected ? "wifi" : "wifi.slash")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(monitor.isConnected ? DS.Colors.accentBlue : .red)
                
                Text(monitor.connectionType.uppercased())
                    .font(DS.Fonts.microMono)
                    .foregroundStyle(DS.Colors.textTertiary)
                
                Spacer()
                
                // Connection indicator dot
                Circle()
                    .fill(monitor.isConnected ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
            }
            
            // ── Speed Display ──
            HStack(spacing: 12) {
                // Download
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.cyan)
                    
                    Text(monitor.downloadFormatted)
                        .font(DS.Fonts.captionMono)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
                
                // Upload
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                    
                    Text(monitor.uploadFormatted)
                        .font(DS.Fonts.captionMono)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
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
}

// ═══════════════════════════════════════════════════
// MARK: - Compact Wing Version
// ═══════════════════════════════════════════════════
// For display in collapsed notch wings

struct NetworkSpeedWingView: View {
    @ObservedObject var monitor: NetworkSpeedMonitor
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.down")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.cyan.opacity(0.8))
            
            Text(monitor.downloadFormatted)
                .font(DS.Fonts.microMono)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
