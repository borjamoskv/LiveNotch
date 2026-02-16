import Foundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📊 System Monitor Service
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — CPU, RAM monitoring + Memory Guardian

final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    
    @Published var cpuUsage: Double = 0.0
    @Published var ramUsage: Double = 0.0
    @Published var ramUsedGB: Double = 0.0
    @Published var ramTotalGB: Double = 0.0
    @Published var netDown: Double = 0.0  // KB/s received
    @Published var netUp: Double = 0.0    // KB/s transmitted
    
    // private var timer: Timer? // Removed: managed by SmartPolling
    
    private init() {
        update()
        // Register with SmartPolling coordinator — adaptive rates
        SmartPolling.shared.register("system.monitor", interval: .adaptive(active: 3.0, idle: 10.0)) { [weak self] in
            self?.update()
        }
    }
    
    func update() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let cpu = self.getCPUUsage()
            let ram = self.getRAMUsage()
            
            // 🛡️ MEMORY GUARDIAN
            let usedMB = ProcessInfo.processInfo.physicalMemory > 0
                ? Double(self.getAppMemoryUsage()) / 1_048_576
                : 0
            
            if usedMB > 800 {
                // Critical — aggressive cleanup
                self.optimizeMemory { _ in
                    // Force GC-like behavior
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .init("forceMemoryCleanup"), object: nil)
                    }
                }
            } else if usedMB > 500 {
                // Soft optimize
                self.optimizeMemory { _ in }
            }
            
            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.ramUsage = ram.0
                self.ramUsedGB = ram.1
                self.ramTotalGB = ram.2
            }
        }
    }
    
    func optimizeMemory(onComplete: @escaping (String) -> Void) {
        // Sandboxed "Boost" simulation
        DispatchQueue.global(qos: .utility).async {
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            
            let result = "Memory optimized: caches cleared"
            DispatchQueue.main.async {
                onComplete(result)
            }
        }
    }
    
    private func getAppMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCPUUsage() -> Double {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let userTicks = Double(loadInfo.cpu_ticks.0)
        let systemTicks = Double(loadInfo.cpu_ticks.1)
        let idleTicks = Double(loadInfo.cpu_ticks.2)
        let niceTicks = Double(loadInfo.cpu_ticks.3)
        let total = userTicks + systemTicks + idleTicks + niceTicks
        
        guard total > 0 else { return 0 }
        return ((total - idleTicks) / total) * 100.0
    }
    
    private func getRAMUsage() -> (Double, Double, Double) {
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824
        
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, totalGB) }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed
        let usedGB = usedBytes / 1_073_741_824
        let percentage = (usedBytes / totalBytes) * 100.0
        
        return (percentage, usedGB, totalGB)
    }
}
