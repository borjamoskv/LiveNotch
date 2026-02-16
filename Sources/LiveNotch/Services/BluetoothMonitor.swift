import AppKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🎧 Bluetooth Device Monitor
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — AirPods/headphone detection (Feature #206)

final class BluetoothMonitor: ObservableObject {
    static let shared = BluetoothMonitor()
    
    struct BTDevice: Identifiable {
        let id = UUID()
        let name: String
        let type: DeviceType
        let connected: Bool
        
        enum DeviceType {
            case airpods
            case headphones
            case speaker
            case other
        }
        
        var icon: String {
            switch type {
            case .airpods: return "airpodspro"
            case .headphones: return "headphones"
            case .speaker: return "hifispeaker"
            case .other: return "dot.radiowaves.left.and.right"
            }
        }
    }
    
    @Published var connectedDevice: BTDevice? = nil
    @Published var showConnectAnimation = false
    private let log = NotchLog.make("BluetoothMonitor")
    private var timer: Timer?
    private var lastDeviceName: String = ""
    
    private init() {
        checkAudioDevice()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAudioDevice()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func checkAudioDevice() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPAudioDataType"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    var foundOutput = false
                    var deviceName = ""
                    
                    for line in lines {
                        if line.contains("Output:") {
                            foundOutput = true
                            continue
                        }
                        if foundOutput {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !trimmed.hasPrefix("Items:") {
                                deviceName = trimmed.replacingOccurrences(of: ":", with: "")
                                break
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.processAudioDeviceName(deviceName)
                    }
                }
            } catch {
                self.log.error("Error running system_profiler: \(error.localizedDescription)")
            }
        }
    }
    
    private func processAudioDeviceName(_ deviceName: String) {
        if !deviceName.isEmpty && deviceName != self.lastDeviceName {
            let type: BTDevice.DeviceType
            let lowered = deviceName.lowercased()
            if lowered.contains("airpod") {
                type = .airpods
            } else if lowered.contains("headphone") || lowered.contains("beats") || lowered.contains("sony") || lowered.contains("bose") {
                type = .headphones
            } else if lowered.contains("speaker") || lowered.contains("homepod") {
                type = .speaker
            } else {
                type = .other
            }
            
            let device = BTDevice(name: deviceName, type: type, connected: true)
            self.connectedDevice = device
            
            if self.lastDeviceName != "" && self.lastDeviceName != deviceName {
                self.showConnectAnimation = true
                HapticManager.shared.play(.success)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.showConnectAnimation = false
                }
            }
            self.lastDeviceName = deviceName
        }
    }
}
