import SwiftUI
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════
// MARK: - 🎨 FileTypeColors — Adaptive Color by File Extension
// Ported from OnyxNotch — Border/glow adapts to dropped file types
// ═══════════════════════════════════════════════════

enum FileTypeColors {
    
    /// Returns a color matching the file type category
    static func color(for url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        
        // Image files — warm magenta
        if ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic", "tiff", "bmp", "raw", "ico"].contains(ext) {
            return Color(red: 255/255, green: 64/255, blue: 129/255) // Hot pink
        }
        
        // Video files — electric purple
        if ["mp4", "mov", "avi", "mkv", "webm", "m4v", "flv", "wmv"].contains(ext) {
            return Color(red: 149/255, green: 117/255, blue: 255/255) // Vivid purple
        }
        
        // Audio files — ocean cyan
        if ["mp3", "wav", "flac", "aac", "ogg", "m4a", "aiff", "wma", "opus"].contains(ext) {
            return DS.Colors.cyan
        }
        
        // Code files — neon green
        if ["swift", "py", "js", "ts", "rs", "go", "c", "cpp", "java", "rb", "kt", "php", "html", "css", "json", "yaml", "toml", "xml", "sh", "zsh"].contains(ext) {
            return DS.Colors.signalGreen
        }
        
        // Documents — warm amber
        if ["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "tex", "csv", "xls", "xlsx", "ppt", "pptx"].contains(ext) {
            return DS.Colors.amber
        }
        
        // Archives — steel blue
        if ["zip", "tar", "gz", "rar", "7z", "dmg", "iso", "pkg"].contains(ext) {
            return DS.Colors.accentBlue
        }
        
        // Design files — coral
        if ["psd", "ai", "sketch", "fig", "xd", "blend", "fbx", "obj"].contains(ext) {
            return Color(red: 255/255, green: 111/255, blue: 97/255)
        }
        
        // Fonts — gold
        if ["ttf", "otf", "woff", "woff2"].contains(ext) {
            return DS.Colors.champagneGold
        }
        
        // Default — subtle white glow
        return DS.Colors.textSecondary
    }
    
    /// Returns an emoji icon for the file type
    static func icon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        if ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic"].contains(ext) { return "🖼️" }
        if ["mp4", "mov", "avi", "mkv", "webm"].contains(ext) { return "🎬" }
        if ["mp3", "wav", "flac", "aac", "ogg", "m4a"].contains(ext) { return "🎵" }
        if ["swift", "py", "js", "ts", "rs", "go"].contains(ext) { return "💻" }
        if ["pdf", "doc", "docx", "txt", "md"].contains(ext) { return "📄" }
        if ["zip", "tar", "gz", "rar", "dmg"].contains(ext) { return "📦" }
        if ["psd", "ai", "sketch", "fig"].contains(ext) { return "🎨" }
        
        return "📁"
    }
    
    /// Returns glow intensity based on file count
    static func intensity(for fileCount: Int) -> Double {
        switch fileCount {
        case 0:     return 0.0
        case 1:     return 0.6
        case 2...5: return 0.8
        default:    return 1.0
        }
    }
}
