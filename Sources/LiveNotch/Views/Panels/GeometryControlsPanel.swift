import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🎛️ God Mode: Geometry Controls — Liquid Glass
// ═══════════════════════════════════════════════════

struct GeometryControlsPanel: View {
    @ObservedObject var geometry: NotchGeometry
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(DS.Colors.champagneGold)
                    .shadow(color: DS.Colors.champagneGold.opacity(0.4), radius: 4)
                Text("GOD MODE")
                    .font(DS.Fonts.labelBold)
                    .foregroundColor(DS.Colors.champagneGold)
                Spacer()
                Button(action: {
                    withAnimation(DS.Anim.springStd) { viewModel.isGodModeVisible = false }
                    HapticManager.shared.play(.collapse)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            // Sliders
            Group {
                controlRow(label: "Width", value: $geometry.notchWidth, range: 100...400)
                controlRow(label: "Height", value: $geometry.notchHeight, range: 20...100)
                controlRow(label: "Wing Width", value: $geometry.wingContentWidth, range: 50...400)
                controlRow(label: "Corner Rad", value: $geometry.cornerRadius, range: 0...50)
                controlRow(label: "Top Offset", value: $geometry.topOffset, range: -50...50)
            }
            
            // Liquid glass separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            DS.Colors.champagneGold.opacity(0.12),
                            DS.Colors.glassBorder.opacity(0.3),
                            DS.Colors.champagneGold.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
            
            // Aesthetic Toggles
            Toggle("🔵 Blue YInMn Theme", isOn: $viewModel.isBlueYLM)
                .toggleStyle(SwitchToggleStyle(tint: DS.Colors.yinmnBlue))
                .font(DS.Fonts.label)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            ZStack {
                // Glass material base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                // Depth gradient
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.glassLayer1, DS.Colors.glassLayer2, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            DS.Colors.champagneGold.opacity(0.25),
                            DS.Colors.glassBorder,
                            .clear,
                            DS.Colors.champagneGold.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, y: 8)
        .shadow(color: DS.Colors.champagneGold.opacity(0.06), radius: 20, y: 4)
        .frame(width: 300)
    }
    
    private func controlRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(DS.Fonts.micro)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(DS.Fonts.code)
                    .foregroundColor(DS.Colors.champagneGold)
            }
            Slider(value: value, in: range)
                .accentColor(DS.Colors.champagneGold)
        }
    }
}
