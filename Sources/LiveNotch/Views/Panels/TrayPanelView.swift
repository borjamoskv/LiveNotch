import SwiftUI

struct TrayPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            PanelHeader(
                icon: "tray.full.fill",
                iconColor: .orange,
                title: L10n.fileTray,
                trailing: {
                    HStack(spacing: 6) {
                        Text("\(viewModel.droppedFiles.count) files")
                            .font(DS.Fonts.tinyMono)
                            .foregroundColor(.orange.opacity(0.6))
                        
                        Button(action: {
                            viewModel.droppedFiles.removeAll()
                            HapticManager.shared.play(.toggle)
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .font(DS.Fonts.body)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                },
                onClose: {
                    viewModel.droppedFiles.removeAll()
                    viewModel.isExpanded = false
                }
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(viewModel.droppedFiles, id: \.absoluteString) { file in
                        VStack(spacing: 4) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                            Text(file.lastPathComponent)
                                .font(DS.Fonts.micro)
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            NSWorkspace.shared.open(file)
                        }
                    }
                }
            }
            .frame(maxHeight: 130)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
