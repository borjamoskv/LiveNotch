import SwiftUI
import Charts // If supported, otherwise custom Path

// ═══════════════════════════════════════════════════
// MARK: - 🛡️ VANGUARD TELEMETRY
// ═══════════════════════════════════════════════════

struct VanguardView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var network = NetworkService.shared
    
    // Sparkline History (Kept local for view state)
    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 40)
    @State private var netDownHistory: [Double] = Array(repeating: 0, count: 40)
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("SYSTEM.VANGUARD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                // Server Status & Latency
                HStack(spacing: 6) {
                    if network.serverStatus == .online {
                        Text(String(format: "%.0fms", network.lastLatency))
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    
                    Text(statusText)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .padding(.horizontal, 4)
            
            // 1. CPU Core (Amber)
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Colors.amber)
                    Text("\(Int(monitor.cpuUsage))%")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(DS.Colors.amber)
                        .contentTransition(.numericText())
                }
                
                // Sparkline
                Sparkline(data: cpuHistory, color: DS.Colors.amber)
                    .frame(height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(DS.Colors.amber.opacity(0.2), lineWidth: 0.5)
                    )
            }
            
            // 2. Memory Grid (Cyan)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RAM")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Colors.cyan)
                    Text(String(format: "%.1f", monitor.ramUsedGB))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.Colors.cyan)
                    + Text("GB")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.Colors.cyan.opacity(0.6))
                }
                
                // Bar Gauge
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DS.Colors.cyan.opacity(0.1))
                        Rectangle()
                            .fill(DS.Colors.cyan)
                            .frame(width: geo.size.width * (monitor.ramUsage / 100.0))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
                
                Text("\(Int(monitor.ramUsage))%")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(DS.Colors.cyan)
                    .frame(width: 30, alignment: .trailing)
            }
            
            // 3. Network I/O (Green)
            HStack(spacing: 12) {
                // Down
                VStack(alignment: .leading, spacing: 0) {
                    Text("RX")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Colors.signalGreen.opacity(0.7))
                    Text(formatBytes(monitor.netDown))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.Colors.signalGreen)
                }
                
                Spacer()
                
                // Net Graph (Placeholder or simple activity)
                 Sparkline(data: netDownHistory, color: DS.Colors.signalGreen)
                    .frame(height: 16)
                    .frame(width: 60)
                    .opacity(0.5)
                
                Spacer()
                
                // Up
                VStack(alignment: .trailing, spacing: 0) {
                    Text("TX")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Colors.amber.opacity(0.7)) // TX usually amber/orange
                    Text(formatBytes(monitor.netUp))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.Colors.amber)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .onReceive(timer) { _ in
            // Update Histories
            withAnimation(DS.Spring.snap) {
                updateHistories()
            }
        }
    }
    
    func updateHistories() {
        // CPU
        cpuHistory.append(monitor.cpuUsage)
        if cpuHistory.count > 40 { cpuHistory.removeFirst() }
        
        // Net Down (Normalized for visual)
        // Cap visual at 5MB/s for "full scale" effect? or just log scale?
        // Let's just push raw for now, Path will normalize.
        netDownHistory.append(min(monitor.netDown, 5000)) // Cap visual at 5MB/s
        if netDownHistory.count > 40 { netDownHistory.removeFirst() }
    }
    
    func formatBytes(_ kb: Double) -> String {
        if kb > 1024 {
            return String(format: "%.1f MB/s", kb/1024)
        } else {
            return String(format: "%.0f KB/s", kb)
        }
    }
    
    var statusColor: Color {
        switch network.serverStatus {
        case .online: return DS.Colors.signalGreen
        case .degraded: return DS.Colors.amber
        case .offline: return .red
        case .unknown: return .gray
        }
    }
    
    var statusText: String {
        switch network.serverStatus {
        case .online: return "ONLINE"
        case .degraded: return "DEGRADED"
        case .offline: return "OFFLINE"
        case .unknown: return "CONNECTING"
        }
    }
}

// Minimal Sparkline (Path based)
struct Sparkline: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let path = Path { p in
                guard data.count > 1 else { return }
                
                let stepX = geo.size.width / CGFloat(data.count - 1)
                let maxY = (data.max() ?? 100)
                let scaleY = geo.size.height / (maxY > 0 ? CGFloat(maxY) : 1)
                
                p.move(to: CGPoint(x: 0, y: geo.size.height - (CGFloat(data[0]) * scaleY)))
                
                for i in 1..<data.count {
                    let pf = CGPoint(x: CGFloat(i) * stepX, y: geo.size.height - (CGFloat(data[i]) * scaleY))
                    p.addLine(to: pf)
                }
            }
            
            path.stroke(color, lineWidth: 1.5)
        }
    }
}
