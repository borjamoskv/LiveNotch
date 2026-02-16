import SwiftUI

struct VolumeMixerPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var mixer: PerAppVolumeMixer
    
    var body: some View {
        VStack(spacing: 8) {
            PanelHeader(
                icon: "speaker.wave.3.fill",
                iconColor: .blue,
                title: L10n.volumeMixer,
                trailing: {
                    Text("\(mixer.audioApps.count) apps")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(.white.opacity(0.3))
                },
                onClose: { viewModel.isVolumeMixerVisible = false }
            )
            
            if mixer.audioApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 24, weight: .ultraLight)) // unique ultra-light — no token
                        .foregroundColor(.white.opacity(0.12))
                    Text("No audio apps running")
                        .font(DS.Fonts.body)
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(mixer.audioApps) { app in
                            mixerAppRow(app)
                        }
                    }
                }
                .frame(maxHeight: 160)
                .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    func mixerAppRow(_ app: PerAppVolumeMixer.AppAudio) -> some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .shadow(color: DS.Shadow.md, radius: 2, y: 1)
            } else {
                Image(systemName: "app.fill")
                    .font(DS.Fonts.h3)
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 22, height: 22)
            }
            
            Text(app.name)
                .font(DS.Fonts.body)
                .foregroundColor(.white.opacity(0.65))
                .frame(width: 65, alignment: .leading)
                .lineLimit(1)
            
            NotchVolumeSlider(
                volume: Binding(
                    get: { (app.isMuted ? 0 : app.volume) * 100 },
                    set: { newValue in
                        mixer.setVolume(for: app.id, volume: Float(newValue / 100))
                    }
                ),
                color: app.isMuted ? .gray : .blue
            )
            .frame(maxWidth: .infinity)
            
            Text("\(Int((app.isMuted ? 0 : app.volume) * 100))%")
                .font(DS.Fonts.tinyMono)
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 30)
            
            Button(action: {
                mixer.toggleMute(for: app.id)
                HapticManager.shared.play(.toggle)
            }) {
                Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(DS.Fonts.small)
                .foregroundColor(app.isMuted ? .red.opacity(0.6) : .white.opacity(0.35))
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.Colors.surfaceFaint)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.strokeFaint, lineWidth: 0.5)
        )
    }
}
