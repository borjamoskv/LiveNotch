import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Album Art Service
// ═══════════════════════════════════════════════════
// Extracted from MusicController — single download, art + color extraction.
// Eliminates the duplicate-download bug where the same URL was fetched twice.

@MainActor
final class AlbumArtService {
    
    // ── Color Extraction Constants ──
    private enum Constants {
        static let sampleGridSize = 12
        static let saturationThreshold: CGFloat = 0.10
        static let primaryBoost: CGFloat = 1.5
        static let secondaryBoost: CGFloat = 1.2
    }
    
    struct ArtResult {
        let image: NSImage
        let primaryColor: Color
        let secondaryColor: Color
    }
    
    // ── Default Colors ──
    static let defaultPrimary = Color(red: 0.4, green: 0.75, blue: 1.0)
    static let defaultSecondary = Color(red: 0.75, green: 0.4, blue: 1.0)
    
    /// Fetches album art from URL and extracts dominant colors in a single download.
    func fetchArtAndColors(from urlStr: String) async -> ArtResult? {
        guard let url = URL(string: urlStr) else { return nil }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = try? Data(contentsOf: url),
                      let image = NSImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let colors = Self.extractColors(from: image)
                continuation.resume(returning: ArtResult(
                    image: image,
                    primaryColor: colors.primary,
                    secondaryColor: colors.secondary
                ))
            }
        }
    }
    
    /// Extracts dominant colors from an image by sampling the center region.
    nonisolated static func extractColors(from image: NSImage) -> (primary: Color, secondary: Color) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return (defaultPrimary, defaultSecondary)
        }
        
        var redTotal: CGFloat = 0
        var greenTotal: CGFloat = 0
        var blueTotal: CGFloat = 0
        var sampleCount: CGFloat = 0
        
        let grid = Constants.sampleGridSize
        for i in 0..<grid {
            for j in 0..<grid {
                let x = bitmap.pixelsWide / 4 + i * (bitmap.pixelsWide / (grid * 2))
                let y = bitmap.pixelsHigh / 4 + j * (bitmap.pixelsHigh / (grid * 2))
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    redTotal += color.redComponent
                    greenTotal += color.greenComponent
                    blueTotal += color.blueComponent
                    sampleCount += 1
                }
            }
        }
        
        guard sampleCount > 0 else { return (defaultPrimary, defaultSecondary) }
        
        let r = redTotal / sampleCount
        let g = greenTotal / sampleCount
        let b = blueTotal / sampleCount
        let maxChannel = max(r, g, b)
        let saturation = maxChannel > 0 ? (maxChannel - min(r, g, b)) / maxChannel : 0
        
        if saturation > Constants.saturationThreshold {
            let primary = Color(
                red: min(1, r * Constants.primaryBoost),
                green: min(1, g * Constants.primaryBoost),
                blue: min(1, b * Constants.primaryBoost)
            )
            let secondary = Color(
                red: min(1, b * Constants.secondaryBoost),
                green: min(1, r * Constants.secondaryBoost),
                blue: min(1, g * Constants.secondaryBoost)
            )
            return (primary, secondary)
        } else {
            return (defaultPrimary, defaultSecondary)
        }
    }
}
