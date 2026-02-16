import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Design Tokens
// ═══════════════════════════════════════════════════
// Single source of truth for ALL repeated visual constants.
// Eliminates hardcoded magic numbers across 8+ files.

enum DS {
    
    // ── Corner Radii ──
    // Before: 8 different values scattered (4, 5, 6, 8, 10, 12, 14, 16)
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
        static let panel: CGFloat = 16
    }
    
    // ── Spacing (Padding) ──
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
        static let section: CGFloat = 16
    }
    
    // ── Font Presets ──
    // Deduplicates 15+ repeated .font(.system(size:...)) calls
    enum Fonts {
        static let micro      = Font.system(size: 7, weight: .medium)
        static let microMono  = Font.system(size: 7, weight: .medium, design: .monospaced)
        static let microBold  = Font.system(size: 7, weight: .bold, design: .monospaced)
        
        static let tiny       = Font.system(size: 8, weight: .medium)
        static let tinyBold   = Font.system(size: 8, weight: .bold)
        static let tinyMono   = Font.system(size: 8, weight: .bold, design: .monospaced)
        static let tinySemi   = Font.system(size: 8, weight: .semibold)
        static let tinyRound  = Font.system(size: 8, weight: .medium, design: .rounded)
        
        static let small      = Font.system(size: 9, weight: .medium)
        static let smallBold  = Font.system(size: 9, weight: .bold)
        static let smallMono  = Font.system(size: 9, weight: .medium, design: .monospaced)
        static let smallRound = Font.system(size: 9, weight: .medium, design: .rounded)
        
        static let body       = Font.system(size: 10, weight: .medium)
        static let bodySemi   = Font.system(size: 10, weight: .semibold)
        static let bodyBold   = Font.system(size: 10, weight: .bold)
        static let bodyRound  = Font.system(size: 10, weight: .medium, design: .rounded)
        static let bodyMono   = Font.system(size: 10, weight: .medium, design: .monospaced)
        
        static let caption    = Font.system(size: 9, weight: .regular)
        static let captionBold = Font.system(size: 9, weight: .bold)
        static let captionMono = Font.system(size: 9, weight: .medium, design: .monospaced)
        
        static let code       = Font.system(size: 10, weight: .medium, design: .monospaced)
        
        static let label      = Font.system(size: 11, weight: .medium)
        static let labelSemi  = Font.system(size: 11, weight: .semibold)
        static let labelBold  = Font.system(size: 11, weight: .bold, design: .rounded)
        static let labelMono  = Font.system(size: 11, weight: .semibold, design: .monospaced)
        
        static let title      = Font.system(size: 12, weight: .semibold)
        static let titleBold  = Font.system(size: 13, weight: .bold)
        
        static let h4         = Font.system(size: 14, weight: .semibold)
        static let h3         = Font.system(size: 16, weight: .bold)
        static let h2         = Font.system(size: 22, weight: .regular)
    }
    
    // ── Color Palette ──
    // Deduplicates 36+ opacity variations
    enum Colors {
        // White hierarchy (most used)
        static let textPrimary   = Color.white.opacity(0.85)
        static let textSecondary = Color.white.opacity(0.6)
        static let textTertiary  = Color.white.opacity(0.4)
        static let textMuted     = Color.white.opacity(0.3)
        static let textFaint     = Color.white.opacity(0.25)
        static let textGhost     = Color.white.opacity(0.2)
        static let textDim       = Color.white.opacity(0.15)
        static let textInvisible = Color.white.opacity(0.08)
        
        // Surfaces — Premium Alcove-level depth
        static let surfaceLight  = Color.white.opacity(0.06)
        static let surfaceCard   = Color.white.opacity(0.04)
        static let surfaceSubtle = Color.white.opacity(0.03)
        static let surfaceFaint  = Color.white.opacity(0.025)
        static let surfaceVoid   = Color.white.opacity(0.018) // Deepest — near-invisible
        static let surfaceInner  = Color.white.opacity(0.012) // Inner body — Alcove black
        
        // Strokes — Premium hairline
        static let strokeLight   = Color.white.opacity(0.08)
        static let strokeSubtle  = Color.white.opacity(0.04)
        static let strokeFaint   = Color.white.opacity(0.03)
        static let strokeHairline = Color.white.opacity(0.015) // Near-invisible edge
        
        // Premium inner highlight — the subtle "glass edge" that makes it feel 3D
        static let innerHighlight = Color.white.opacity(0.04)
        
        // ── Premium Accent Colors ──
        // YInMn Blue — rarest modern pigment (discovered 2009, Oregon State)
        static let yinmnBlue = Color(red: 46/255, green: 80/255, blue: 144/255)
        // Klein Blue — International Klein Blue (IKB)
        static let kleinBlue = Color(red: 0/255, green: 47/255, blue: 167/255)
        // Eigengrau — the color you see in total darkness
        static let eigengrau = Color(red: 22/255, green: 22/255, blue: 29/255)
        
        // ── Accent Colors ──
        static let accentBlue    = Color(red: 46/255, green: 120/255, blue: 255/255) // Primary action blue
        static let amber         = Color(red: 255/255, green: 191/255, blue: 0/255)   // Warning/attention amber
        static let cyan          = Color(red: 0/255, green: 210/255, blue: 235/255)   // Cool info/utility cyan
        static let signalGreen   = Color(red: 50/255, green: 215/255, blue: 75/255)   // Status OK / healthy green
        
        // ── Background Surfaces ──
        static let bgDark        = Color(red: 15/255, green: 15/255, blue: 20/255) // Deep dark background
        
        // ── Liquid Glass System ──
        // Champagne gold — warm premium accent (like lacquered brass)
        static let champagneGold = Color(red: 212/255, green: 175/255, blue: 110/255)
        // Glass layering — progressive translucent depth
        static let glassLayer1   = Color.white.opacity(0.06)
        static let glassLayer2   = Color.white.opacity(0.03)
        static let glassLayer3   = Color.white.opacity(0.015)
        static let glassBorder   = Color.white.opacity(0.08)
        
        // Shadows — deeper for premium depth
        static let shadowMd      = Color.black.opacity(0.2)
        static let shadowLg      = Color.black.opacity(0.3)
        static let shadowDeep    = Color.black.opacity(0.5)
        static let shadowAbyss   = Color.black.opacity(0.7)
    }
    
    // ═══════════════════════════════════════════════════
    // MARK: - 🧲 NotchSpring — Semantic Physics Tokens
    // ═══════════════════════════════════════════════════
    // 4 semantic tokens. Modern spring(response:dampingFraction:) API.
    // Tweak mass/feel of the ENTIRE app from here. Zero inline springs.
    //
    //   .snappy      → toggles, taps, micro-interactions (crisp, tight)
    //   .liquid      → panel expand/collapse, morphing (fluid, organic)
    //   .heavyBounce → drag release, drop, detach (weighty, satisfying)
    //   .breath      → ambient glow, idle pulse (slow, living)
    
    enum NotchSpring {
        /// Toggles, taps, icon scale, micro-interactions — crisp & tight
        static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.75)
        
        /// Panel expand/collapse, content morphing — fluid & organic
        static let liquid = Animation.spring(response: 0.45, dampingFraction: 0.72, blendDuration: 0.1)
        
        /// Drag release, drop, detach, notifications — weighty & satisfying
        static let heavyBounce = Animation.spring(response: 0.55, dampingFraction: 0.6)
        
        /// Ambient pulsing, glow loops — slow & living
        static let breath = Animation.spring(response: 1.2, dampingFraction: 0.85)
    }
    
    // ── Backward-Compatible: DS.Spring → NotchSpring ──
    // Old call sites compile unchanged. Migrate gradually.
    enum Spring {
        static let island  = NotchSpring.snappy
        static let snap    = NotchSpring.snappy
        static let micro   = NotchSpring.snappy
        static let soft    = NotchSpring.liquid
        static let liquid  = NotchSpring.liquid
        static let bounce  = NotchSpring.heavyBounce
        static let heavy   = NotchSpring.heavyBounce
        static let breath  = NotchSpring.breath
    }
    
    // ── Backward-Compatible: DS.Anim → NotchSpring ──
    enum Anim {
        static let springFast   = NotchSpring.snappy
        static let springSnap   = NotchSpring.snappy
        static let springStd    = NotchSpring.snappy
        static let springSoft   = NotchSpring.liquid
        static let springNotify = NotchSpring.heavyBounce
        static let liquidSpring = NotchSpring.liquid
        static let breathe      = NotchSpring.breath
        static let easeQuick    = NotchSpring.snappy
        static let easeMedium   = NotchSpring.liquid
    }
    
    // ── Icon Sizes ──
    enum Icons {
        static let micro: CGFloat  = 6
        static let tiny: CGFloat   = 8
        static let small: CGFloat  = 11
        static let body: CGFloat   = 14
        static let large: CGFloat  = 16
        static let xl: CGFloat     = 18
        static let xxl: CGFloat    = 22
    }
    
    // ── Standard Layout Dimensions ──
    enum Layout {
        static let wingIcon: CGFloat    = 18
        static let wingAlbum: CGFloat   = 22
        static let waveW: CGFloat       = 12
        static let waveH: CGFloat       = 10
        static let ringOuter: CGFloat   = 26
        static let ringInner: CGFloat   = 18
        static let gridButtonH: CGFloat = 44
        static let actionButtonH: CGFloat = 36
        static let glanceIcon: CGFloat  = 18
        static let btIcon: CGFloat      = 16
    }
    
    // ── Shadow Presets ──
    enum Shadow {
        static let sm = Color.black.opacity(0.15)
        static let md = Color.black.opacity(0.2)
        static let lg = Color.black.opacity(0.3)
        static let xl = Color.black.opacity(0.35)
        static let deep = Color.black.opacity(0.55)  // Alcove-level depth
        static let abyss = Color.black.opacity(0.75) // Maximum depth
    }
    
    // ── Stroke Helpers ──
    static func cardStroke(_ color: Color = Colors.strokeLight) -> some ShapeStyle {
        color
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Gesture Notifications
// ═══════════════════════════════════════════════════

extension Notification.Name {
    static let gestureToggleAI = Notification.Name("gestureToggleAI")
    static let gestureClipboardAI = Notification.Name("gestureClipboardAI")
    static let gestureToggleNotch = Notification.Name("gestureToggleNotch")
    static let gestureSummonBrain = Notification.Name("gestureSummonBrain")
}
