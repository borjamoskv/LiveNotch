import SwiftUI

struct PanelHeader<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let trailing: Trailing
    let onClose: () -> Void
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing,
        onClose: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing()
        self.onClose = onClose
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(DS.Fonts.title)
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.4), radius: 4)
                Text(title)
                    .font(DS.Fonts.labelBold)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            Spacer()
            
            trailing
            
            Button(action: {
                onClose()
                HapticManager.shared.play(.toggle)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Fonts.title)
                    .foregroundColor(DS.Colors.textMuted)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.Space.section)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(
        icon: String,
        iconColor: Color,
        title: String,
        onClose: @escaping () -> Void
    ) {
        self.init(icon: icon, iconColor: iconColor, title: title, trailing: { EmptyView() }, onClose: onClose)
    }
}
