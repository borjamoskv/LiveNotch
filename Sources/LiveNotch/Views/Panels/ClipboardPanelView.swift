import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var clipboard: ClipboardManager
    
    var body: some View {
        VStack(spacing: 8) {
            PanelHeader(
                icon: "doc.on.clipboard.fill",
                iconColor: .cyan,
                title: L10n.clipboard,
                trailing: {
                    if !clipboard.items.isEmpty {
                        HStack(spacing: 6) {
                            Text("\(clipboard.items.count)")
                                .font(DS.Fonts.tinyMono)
                                .foregroundColor(.cyan.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.08))
                                .clipShape(Capsule())
                            
                            Button(action: {
                                clipboard.clear()
                                HapticManager.shared.play(.toggle)
                            }) {
                                Text("Clear")
                                    .font(DS.Fonts.tinyRound)
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                },
                onClose: { viewModel.isClipboardVisible = false }
            )
            
            if clipboard.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 24, weight: .ultraLight)) // unique ultra-light — no token
                        .foregroundColor(.white.opacity(0.1))
                    Text("Clipboard is empty")
                        .font(DS.Fonts.bodyRound)
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(height: 90)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(clipboard.items.prefix(10)) { item in
                            ClipboardItemView(item: item) {
                                clipboard.copyItem(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
