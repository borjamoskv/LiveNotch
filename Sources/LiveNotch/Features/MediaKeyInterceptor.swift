//
//  MediaKeyInterceptor.swift
//  LiveNotch
//
//  Created by Alexander on 2025-11-23.
//

import Foundation
import AppKit
import ApplicationServices
import AVFoundation

private let log = NotchLog.make("MediaKeys")
private let kSystemDefinedEventType = CGEventType(rawValue: 14) ?? .null

final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    private enum NXKeyType: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case keyboardBrightnessUp = 21
        case keyboardBrightnessDown = 22
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let step: Float = 1.0 / 16.0
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    func start() {
        guard eventTap == nil else { return }
        
        // Authorization check (AXIsProcessTrusted)
        if !AXIsProcessTrusted() {
            log.warning("Not authorized for accessibility.")
            // Prompting should happen in UI
            return
        }
        
        let mask = CGEventMask(1 << kSystemDefinedEventType.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, cgEvent, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(cgEvent) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handleEvent(cgEvent)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            log.started("MediaKeyInterceptor")
        }
    }
    
    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        log.info("MediaKeyInterceptor stopped.")
    }
    
    private func handleEvent(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard cgEvent.type != .null else {
            return Unmanaged.passRetained(cgEvent)
        }
        guard let nsEvent = NSEvent(cgEvent: cgEvent),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(cgEvent)
        }
        
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let stateByte = ((data1 & 0xFF00) >> 8)
        
        // 0xA = key down, 0xB = key up.
        guard stateByte == 0xA,
              let keyType = NXKeyType(rawValue: keyCode) else {
            return Unmanaged.passRetained(cgEvent)
        }
        
        handleKeyPress(keyType: keyType)
        return nil // Intercepted
    }
    
    private func handleKeyPress(keyType: NXKeyType) {
        Task { @MainActor in
            switch keyType {
            case .soundUp:
                self.playFeedbackSound()
                IntegratedHUDManager.shared.adjustVolume(delta: step)
            case .soundDown:
                self.playFeedbackSound()
                IntegratedHUDManager.shared.adjustVolume(delta: -step)
            case .mute:
                IntegratedHUDManager.shared.toggleMute()
            case .brightnessUp:
                IntegratedHUDManager.shared.adjustBrightness(delta: step)
            case .brightnessDown:
                IntegratedHUDManager.shared.adjustBrightness(delta: -step)
            default:
                break
            }
        }
    }
    
    private func playFeedbackSound() {
        // System volume feedback sound logic
        let defaultPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        if audioPlayer == nil, FileManager.default.fileExists(atPath: defaultPath) {
            audioPlayer = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: defaultPath))
            audioPlayer?.prepareToPlay()
        }
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
