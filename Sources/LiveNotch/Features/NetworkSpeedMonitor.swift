import SwiftUI
import Network
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🌐 Network Speed Monitor
// ═══════════════════════════════════════════════════
// Real-time upload/download speed via sysctl + NWPathMonitor.
// Same approach as iStat Menus / Stats — reads interface bytes/sec.

@MainActor
final class NetworkSpeedMonitor: ObservableObject {
    static let shared = NetworkSpeedMonitor()
    
    // ── Published State ──
    @Published var isConnected = true
    @Published var connectionType: String = "WiFi"
    @Published var downloadSpeed: UInt64 = 0  // bytes/sec
    @Published var uploadSpeed: UInt64 = 0    // bytes/sec
    @Published var downloadFormatted: String = "0 B/s"
    @Published var uploadFormatted: String = "0 B/s"
    
    // ── Internals ──
    private var pathMonitor: NWPathMonitor?
    private var speedTimer: Timer?
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private let updateInterval: TimeInterval = 1.0
    
    private init() {
        setupPathMonitor()
        // Initialize baseline
        let stats = readInterfaceStats()
        lastBytesIn = stats.bytesIn
        lastBytesOut = stats.bytesOut
    }
    
    // ════════════════════════════════════════
    // MARK: - Start / Stop
    // ════════════════════════════════════════
    
    func start() {
        guard speedTimer == nil else { return }
        speedTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateSpeeds() }
        }
        NSLog("🌐 NetworkSpeedMonitor started")
    }
    
    func stop() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
    
    // ════════════════════════════════════════
    // MARK: - NWPathMonitor
    // ════════════════════════════════════════
    
    private func setupPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Cellular"
                } else {
                    self?.connectionType = "Other"
                }
            }
        }
        pathMonitor?.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    // ════════════════════════════════════════
    // MARK: - Speed Calculation (sysctl)
    // ════════════════════════════════════════
    
    private func updateSpeeds() {
        let stats = readInterfaceStats()
        
        let deltaIn = stats.bytesIn >= lastBytesIn ? stats.bytesIn - lastBytesIn : 0
        let deltaOut = stats.bytesOut >= lastBytesOut ? stats.bytesOut - lastBytesOut : 0
        
        lastBytesIn = stats.bytesIn
        lastBytesOut = stats.bytesOut
        
        downloadSpeed = deltaIn
        uploadSpeed = deltaOut
        downloadFormatted = Self.formatSpeed(deltaIn)
        uploadFormatted = Self.formatSpeed(deltaOut)
    }
    
    /// Read cumulative network interface statistics via sysctl
    private func readInterfaceStats() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: size_t = 0
        
        // First call: get buffer size
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else { return (0, 0) }
        
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { buf.deallocate() }
        
        // Second call: fill buffer
        guard sysctl(&mib, 6, buf, &len, nil, 0) == 0 else { return (0, 0) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr = buf
        let end = buf.advanced(by: len)
        
        while ptr < end {
            let ifm = ptr.withMemoryRebound(to: if_msghdr.self, capacity: 1) { $0.pointee }
            let msgLen = Int(ifm.ifm_msglen)
            guard msgLen > 0 else { break }
            
            if Int32(ifm.ifm_type) == RTM_IFINFO2 {
                ptr.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { ifm2Ptr in
                    let ifm2 = ifm2Ptr.pointee
                    totalIn += ifm2.ifm_data.ifi_ibytes
                    totalOut += ifm2.ifm_data.ifi_obytes
                }
            }
            
            ptr = ptr.advanced(by: msgLen)
        }
        
        return (totalIn, totalOut)
    }
    
    // ════════════════════════════════════════
    // MARK: - Formatting
    // ════════════════════════════════════════
    
    static func formatSpeed(_ bytesPerSec: UInt64) -> String {
        switch bytesPerSec {
        case 0..<1024:
            return "\(bytesPerSec) B/s"
        case 1024..<(1024 * 1024):
            let kb = Double(bytesPerSec) / 1024.0
            return String(format: "%.1f KB/s", kb)
        case (1024 * 1024)..<(1024 * 1024 * 1024):
            let mb = Double(bytesPerSec) / (1024.0 * 1024.0)
            return String(format: "%.1f MB/s", mb)
        default:
            let gb = Double(bytesPerSec) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB/s", gb)
        }
    }
    
    deinit {
        speedTimer?.invalidate()
        pathMonitor?.cancel()
    }
}
