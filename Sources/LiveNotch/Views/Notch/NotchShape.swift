import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🔮 Continuous Notch Shape (Alcove)
// ═══════════════════════════════════════════════════

struct ContinuousNotchShape: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let cornerRadius: CGFloat
    
    // Animatable for smooth transitions
    var animatableData: CGFloat {
        get { cornerRadius }
        set { } 
    }
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cr = cornerRadius
        let nw = notchWidth
        let nh = min(notchHeight, rect.height)
        let cx = rect.midX
        let notchL = cx - nw / 2
        let notchR = cx + nw / 2
        
        // Smoothing parameters for the "Liquid" look
        // The top join is where the notch meets the bezel (y=0).
        // The bottom join is the bottom corners of the notch.
        let topSmooth: CGFloat = 16
        let bottomSmooth: CGFloat = 20
        
        // 1. Start Top Left (Bezel)
        p.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))
        
        // 2. Approach Notch Top-Left
        let startNotch = notchL - topSmooth
        p.addLine(to: CGPoint(x: startNotch, y: rect.minY))
        
        // 3. Curve: Bezel -> Notch Side (Concave Blend)
        // Smooth transition from Horizontal (y=0) to Vertical-ish
        p.addCurve(
            to: CGPoint(x: notchL, y: rect.minY + topSmooth),
            control1: CGPoint(x: notchL - topSmooth/2, y: rect.minY),
            control2: CGPoint(x: notchL, y: rect.minY)
        )
        
        // 4. Line Down (Notch Left Side)
        p.addLine(to: CGPoint(x: notchL, y: nh - bottomSmooth))
        
        // 5. Curve: Notch Side -> Notch Bottom (Convex Rounded)
        p.addCurve(
            to: CGPoint(x: notchL + bottomSmooth, y: nh),
            control1: CGPoint(x: notchL, y: nh),
            control2: CGPoint(x: notchL, y: nh)
        )
        
        // 6. Line Across (Notch Bottom)
        p.addLine(to: CGPoint(x: notchR - bottomSmooth, y: nh))
        
        // 7. Curve: Notch Bottom -> Notch Right Side (Convex Rounded)
        p.addCurve(
            to: CGPoint(x: notchR, y: nh - bottomSmooth),
            control1: CGPoint(x: notchR, y: nh),
            control2: CGPoint(x: notchR, y: nh)
        )
        
        // 8. Line Up (Notch Right Side)
        p.addLine(to: CGPoint(x: notchR, y: rect.minY + topSmooth))
        
        // 9. Curve: Notch Side -> Bezel (Concave Blend)
        p.addCurve(
            to: CGPoint(x: notchR + topSmooth, y: rect.minY),
            control1: CGPoint(x: notchR, y: rect.minY),
            control2: CGPoint(x: notchR + topSmooth/2, y: rect.minY)
        )
        
        // 10. To Top Right
        p.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
        
        // 11. Standard Corners (Right -> Bottom -> Left -> Top)
        p.addArc(center: CGPoint(x: rect.maxX - cr, y: rect.minY + cr),
                 radius: cr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cr))
        p.addArc(center: CGPoint(x: rect.maxX - cr, y: rect.maxY - cr),
                 radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + cr, y: rect.maxY - cr),
                 radius: cr, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        p.addArc(center: CGPoint(x: rect.minX + cr, y: rect.minY + cr),
                 radius: cr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        
        p.closeSubpath()
        return p
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎵 Audio Waveform Visualizer
// ═══════════════════════════════════════════════════

struct WaveformView: View {
    let color: Color
    let playing: Bool
    let bars: Int
    var style: WaveformStyle = .standard
    
    enum WaveformStyle { case standard, mini, spectral }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { tl in
            Canvas { ctx, sz in
                let t = tl.date.timeIntervalSinceReferenceDate
                switch style {
                case .standard: drawStandard(ctx: ctx, sz: sz, t: t)
                case .mini:     drawMini(ctx: ctx, sz: sz, t: t)
                case .spectral: drawSpectral(ctx: ctx, sz: sz, t: t)
                }
            }
        }
    }
    
    private func drawStandard(ctx: GraphicsContext, sz: CGSize, t: Double) {
        let bw: CGFloat = 2.5, sp: CGFloat = 2
        let tw = CGFloat(bars) * (bw + sp) - sp
        let sx = (sz.width - tw) / 2
        for i in 0..<bars {
            let x = sx + CGFloat(i) * (bw + sp)
            let h: CGFloat = playing
                ? max(3, sz.height * CGFloat(0.35 + sin(t * 4.2 + Double(i) * 0.7) * 0.3 + sin(t * 6.5 + Double(i) * 1.1) * 0.15))
                : 2.5
            let y = (sz.height - h) / 2
            let op = playing ? (0.6 + 0.4 * sin(t * 2.5 + Double(i) * 0.5)) : 0.2
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: bw, height: h), cornerRadius: 1.5),
                     with: .color(color.opacity(op)))
        }
    }
    
    private func drawMini(ctx: GraphicsContext, sz: CGSize, t: Double) {
        let bw: CGFloat = 1.8, sp: CGFloat = 1.2
        let tw = CGFloat(bars) * (bw + sp) - sp
        let sx = (sz.width - tw) / 2
        for i in 0..<bars {
            let x = sx + CGFloat(i) * (bw + sp)
            let h: CGFloat = playing
                ? max(2, sz.height * CGFloat(0.25 + sin(t * 5.5 + Double(i) * 1.1) * 0.4))
                : 1.5
            let y = (sz.height - h) / 2
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: bw, height: h), cornerRadius: 0.9),
                     with: .color(color.opacity(playing ? 0.85 : 0.15)))
        }
    }
    
    private func drawSpectral(ctx: GraphicsContext, sz: CGSize, t: Double) {
        let bw: CGFloat = 2.5, sp: CGFloat = 1.5
        let tw = CGFloat(bars) * (bw + sp) - sp
        let sx = (sz.width - tw) / 2
        for i in 0..<bars {
            let x = sx + CGFloat(i) * (bw + sp)
            let freq = 3.0 + Double(i) * 1.5
            let amp = 0.42 - Double(i) * 0.015
            let h: CGFloat = playing
                ? max(3, sz.height * CGFloat(amp + sin(t * freq) * 0.28 + cos(t * freq * 0.7) * 0.12))
                : 2.0
            let y = sz.height - h
            let barColor = color.opacity(playing ? (0.55 + 0.45 * sin(t * 2.0 + Double(i) * 0.4)) : 0.15)
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: bw, height: h), cornerRadius: 1.25),
                     with: .color(barColor))
            if playing && h > sz.height * 0.55 {
                ctx.fill(Path(roundedRect: CGRect(x: x - 0.5, y: y, width: bw + 1, height: 1.5), cornerRadius: 0.75),
                         with: .color(color.opacity(0.95)))
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🌈 Rotating Gradient Border
// ═══════════════════════════════════════════════════

struct RotatingGradientBorder: View {
    let colors: [Color]
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let cornerRadius: CGFloat
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ContinuousNotchShape(
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            cornerRadius: cornerRadius
        )
        .stroke(
            AngularGradient(
                gradient: Gradient(colors: colors + [colors.first ?? .clear]),
                center: .center,
                angle: .degrees(rotation)
            ),
            lineWidth: 1.2
        )
        .blur(radius: 1.5)
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 📊 Track Progress Bar
// ═══════════════════════════════════════════════════

struct TrackProgressBar: View {
    let progress: Double
    let color: Color
    let color2: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.9), color2.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, geo.size.width * CGFloat(progress)))
                    .animation(DS.Spring.soft, value: progress)
            }
        }
        .frame(height: 2)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎚️ Volume Slider
// ═══════════════════════════════════════════════════

struct NotchVolumeSlider: View {
    @Binding var volume: Float
    let color: Color
    var onChanged: ((Float) -> Void)?
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, geo.size.width * CGFloat(volume / 100.0)))
                
                // Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.4), radius: 3)
                    .offset(x: max(0, min(geo.size.width - 8, geo.size.width * CGFloat(volume / 100.0) - 4)))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newVol = Float(max(0, min(1, value.location.x / geo.size.width))) * 100
                        volume = newVol
                        onChanged?(newVol)
                    }
            )
        }
        .frame(height: 6)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 📋 Clipboard Item View
// ═══════════════════════════════════════════════════

struct ClipboardItemView: View {
    let item: ClipboardManager.ClipItem
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Type icon
                Text(item.isImage ? "📷" : "📝")
                    .font(DS.Fonts.body)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
                
                // Content preview
                Text(item.preview)
                    .font(DS.Fonts.smallRound)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Time
                Text(item.timeAgo)
                    .font(DS.Fonts.tinyMono)
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.06 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.08 : 0.02), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 📅 Calendar Event Badge
// ═══════════════════════════════════════════════════

struct CalendarEventBadge: View {
    let event: CalendarService.CalEvent
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(nsColor: event.urgencyColor))
                .frame(width: 4, height: 4)
                .shadow(color: Color(nsColor: event.urgencyColor).opacity(0.5), radius: 2)
            
            Text(event.timeString)
                .font(DS.Fonts.microBold)
                .foregroundColor(Color(nsColor: event.urgencyColor).opacity(0.8))
            
            Text(event.title)
                .font(DS.Fonts.micro)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Color(nsColor: event.urgencyColor).opacity(0.06)
        )
        .clipShape(Capsule())
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎨 Color Extension
// ═══════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8: (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (1,1,1,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🎯 Scale Button Style
// ═══════════════════════════════════════════════════

struct ScaleButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : (isHovered ? 1.04 : 1.0))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.55), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            .onHover { h in isHovered = h }
    }
}

// ═══════════════════════════════════════════════════
// MARK: - 🌤️ Weather Badge
// ═══════════════════════════════════════════════════

struct WeatherBadge: View {
    @ObservedObject var weather = WeatherService.shared
    
    var body: some View {
        HStack(spacing: 3) {
            Text(weather.condition)
                .font(DS.Fonts.tiny)
            Text(weather.temperature)
                .font(DS.Fonts.tinyRound)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }
}
