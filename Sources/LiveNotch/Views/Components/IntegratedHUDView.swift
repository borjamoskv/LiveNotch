import SwiftUI
import CoreAudio

// ═══════════════════════════════════════════════════
// MARK: - 📊 Integrated HUD — Volume & Brightness
// ═══════════════════════════════════════════════════
// Replaces macOS native overlay with premium notch HUD.
// Appears inside the notch area, matches active theme.

@MainActor
final class IntegratedHUDManager: ObservableObject {
    static let shared = IntegratedHUDManager()
    
    enum HUDType { case volume, brightness }
    
    @Published var isVisible: Bool = false
    @Published var activeHUD: HUDType = .volume
    @Published var value: Float = 0.0  // 0.0 - 1.0
    
    private var dismissTimer: Timer?
    
    private init() {
        self.value = getSystemVolume()
        // We could still poll for changes not triggered by keys (e.g. Menu Bar slider)
        startMonitoring()
    }
    
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkExternalChanges() }
        }
    }
    
    private func checkExternalChanges() {
        if isVisible { return } // Don't fight with our own changes
        
        let vol = getSystemVolume()
        if abs(vol - value) > 0.01 && activeHUD == .volume {
            value = vol
            // We don't necessarily want to show it on external changes unless we want to replace EVERYTHING
            // But for now, let's just keep 'value' updated.
        }
    }
    
    // MARK: - Actions
    
    func adjustVolume(delta: Float) {
        let current = getSystemVolume()
        let target = max(0, min(1, current + delta))
        setSystemVolume(target)
        self.value = target
        show(.volume)
    }
    
    func toggleMute() {
        // Simple mute toggle logic
        if getSystemVolume() > 0 {
            setSystemVolume(0)
            self.value = 0
        } else {
            setSystemVolume(0.25) // Guessing or saving previous
            self.value = 0.25
        }
        show(.volume)
    }
    
    func adjustBrightness(delta: Float) {
        let current = getSystemBrightness()
        let target = max(0, min(1, current + delta))
        setSystemBrightness(target)
        self.value = target
        show(.brightness)
    }
    
    func show(_ type: HUDType) {
        activeHUD = type
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isVisible = true
        }
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(DS.Spring.snap) { self?.isVisible = false }
            }
        }
    }
    
    // MARK: - CoreAudio Volume
    
    private func getSystemVolume() -> Float {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        guard deviceID != 0 else { return 0 }
        
        var volume: Float32 = 0
        size = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &volAddr) {
            AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &size, &volume)
        }
        return volume
    }
    
    private func setSystemVolume(_ value: Float) {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        guard deviceID != 0 else { return }
        
        var volume = Float32(value)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &volAddr) {
            AudioObjectSetPropertyData(deviceID, &volAddr, 0, nil, size, &volume)
        }
    }
    
    // MARK: - DisplayServices Brightness
    
    private func getSystemBrightness() -> Float {
        var b: Float = 0
        if displayServicesGetBrightness(displayID: CGMainDisplayID(), out: &b) {
            return b
        }
        return 0.5
    }
    
    private func setSystemBrightness(_ value: Float) {
        _ = displayServicesSetBrightness(displayID: CGMainDisplayID(), value: value)
    }
    
    private func displayServicesGetBrightness(displayID: CGDirectDisplayID, out: inout Float) -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        var tmp: Float = 0
        let r = fn(displayID, &tmp)
        dlclose(handle)
        if r == 0 { out = tmp; return true }
        return false
    }

    private func displayServicesSetBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        let r = fn(displayID, value)
        dlclose(handle)
        return r == 0
    }
}

// ═══════════════════════════════════════════════════
// MARK: - View
// ═══════════════════════════════════════════════════

struct IntegratedHUDView: View {
    @ObservedObject var hud = IntegratedHUDManager.shared
    
    var body: some View {
        if hud.isVisible {
            HStack(spacing: DS.Space.md) {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: hudIcon)
                        .font(.system(size: DS.Icons.small, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolVariant(.fill)
                        .contentTransition(.interpolate)
                        .frame(width: 20)
                    
                    Text(hudName)
                        .font(DS.Fonts.labelSemi)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(hud.value)))
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(hud.value * 100))%")
                    .font(DS.Fonts.tinyMono)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 35, alignment: .trailing)
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.md)
            .frame(width: 340, height: 32)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
            .environment(\.colorScheme, .dark)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
            ))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
    }
    
    private var hudIcon: String {
        switch hud.activeHUD {
        case .volume:
            if hud.value == 0 { return "speaker.slash" }
            if hud.value < 0.33 { return "speaker.wave.1" }
            if hud.value < 0.66 { return "speaker.wave.2" }
            return "speaker.wave.3"
        case .brightness:
            return hud.value < 0.5 ? "sun.min" : "sun.max"
        }
    }
    
    private var hudName: String {
        switch hud.activeHUD {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        }
    }
}
