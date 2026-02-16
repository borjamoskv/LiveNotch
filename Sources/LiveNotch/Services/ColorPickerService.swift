import SwiftUI
import AppKit

@available(macOS 12.0, *)
class ColorPickerService: ObservableObject {
    static let shared = ColorPickerService()
    
    private let sampler = NSColorSampler()
    
    @Published var isPicking = false
    
    func pickColor(completion: @escaping (NSColor?) -> Void) {
        guard !isPicking else { return }
        isPicking = true
        
        // Slight delay to allow menu closing if triggered via menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sampler.show { selectedColor in
                DispatchQueue.main.async {
                    self.isPicking = false
                    
                    if let color = selectedColor {
                        self.copyToClipboard(color: color)
                        HapticManager.shared.play(.success)
                    } else {
                        // User cancelled
                        HapticManager.shared.play(.subtle)
                    }
                    
                    completion(selectedColor)
                }
            }
        }
    }
    
    private func copyToClipboard(color: NSColor) {
        let hex = color.hexString
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
        NSLog("🎨 Color Picked: %@", hex)
    }
}

extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
