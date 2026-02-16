import SwiftUI

struct MirrorPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var cameraService: CameraService
    
    // Default mirror width from NotchViews
    let mirrorWidth: CGFloat = 340
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                CameraPreview(cameraService: cameraService)
                    .frame(width: mirrorWidth - 32, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .stroke(DS.Colors.strokeLight, lineWidth: 0.5)
                    )
                    .shadow(color: DS.Shadow.lg, radius: 10, y: 4)
                
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.isMirrorActive = false
                            HapticManager.shared.play(.toggle)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(DS.Fonts.h3)
                                .foregroundColor(.white.opacity(0.5))
                                .background(Circle().fill(Color.black.opacity(0.4)))
                                .padding(8)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    Spacer()
                }
            }
            
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Image(systemName: "camera.fill")
                    .font(DS.Fonts.tiny)
                Text(L10n.mirror)
                    .font(DS.Fonts.tinySemi)
            }
            .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
