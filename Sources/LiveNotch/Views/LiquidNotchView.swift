import SwiftUI

@available(macOS 14.0, *)
struct LiquidNotchView: View {
    @State private var mousePosition: CGPoint = .zero
    @State private var isHovering = false
    
    // Config
    var width: CGFloat = 200
    var height: CGFloat = 34
    var topRadius: CGFloat = 0
    var bottomRadius: CGFloat = 14
    var liquidStrength: CGFloat = 20.0 // Base strength
    var color: Color = .black
    var useProxySize: Bool = false
    
    @ObservedObject var nervous = NervousSystem.shared
    
    var body: some View {
        let breathIntensity = nervous.breathIntensity
        let currentMousePos = mousePosition
        
        return TimelineView(.animation) { timeline in
            Canvas { context, size in
            }
            .hidden()
        }
        .overlay(
            Rectangle()
                .fill(color)
                .visualEffect { content, proxy in
                    let size = useProxySize ? proxy.size : CGSize(width: width, height: height)
                    // Dynamic liquid strength based on nervous system breath
                    let dynamicStrength = Float(liquidStrength + (breathIntensity * 15.0))
                    
                    return content
                        .layerEffect(
                            ShaderLibrary.liquidNotch(
                                .float4(0, 0, proxy.size.width, proxy.size.height), // layerBounds
                                .float2(currentMousePos.x - proxy.size.width/2, currentMousePos.y - proxy.size.height/2), // mousePos
                                .float2(size.width, size.height), // notchSize
                                .float4(bottomRadius, topRadius, bottomRadius, topRadius), // TR, BR, TL, BL
                                .float(dynamicStrength),
                                .color(color)
                            ),
                            maxSampleOffset: .zero
                        )
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                isHovering = true
                // Smoothly animate to target?
                // For now, raw position for responsiveness
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.6)) {
                     mousePosition = location
                }
            case .ended:
                isHovering = false
                // Snap back to center or hide
                withAnimation(.spring()) {
                    mousePosition = CGPoint(x: width/2, y: height/2) // Center of notch
                }
            }
        }
    }
}

// Extension to safely load the shader
extension ShaderLibrary {
    static let liquidNotch = ShaderLibrary.default.liquidNotch
}
