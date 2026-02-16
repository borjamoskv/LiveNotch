import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🍞 Status Toast View — Liquid Glass
// ═══════════════════════════════════════════════════
// Extracted from NotchViews.swift — self-contained status overlay

struct StatusToastView: View {
    let message: String
    let icon: String?
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: icon ?? "checkmark.circle.fill")
                .font(.system(size: DS.Icons.body))
                .foregroundStyle(Color.white)
                .shadow(color: DS.Colors.champagneGold.opacity(0.3), radius: 4)
            Text(message)
                .font(DS.Fonts.title)
                .foregroundStyle(Color.white)
        }
        .frame(width: width, height: height)
        .background(
            ZStack {
                // Glass material base
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                // Depth gradient
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.glassLayer1, DS.Colors.glassLayer2, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [DS.Colors.glassBorder, DS.Colors.champagneGold.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
        .shadow(color: DS.Colors.champagneGold.opacity(0.05), radius: 15, y: 2)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }
}
