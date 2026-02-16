import SwiftUI

struct ChronosView: View {
    @ObservedObject var service = ChronosService.shared
    @State private var pulseGlow = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("CHRONOS.FOCUS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                
                // Mode Selector (Simple for now)
                Menu {
                    Button("Focus (25m)") { service.setMode(.focus) }
                    Button("Short Break (5m)") { service.setMode(.shortBreak) }
                    Button("Long Break (15m)") { service.setMode(.longBreak) }
                } label: {
                    Text(service.mode.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(modeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(modeColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Timer Ring
            ZStack {
                // Background Ring
                Circle()
                    .stroke(modeColor.opacity(0.1), lineWidth: 8)
                
                // Progress Ring
                if service.isActive || service.progress < 1.0 {
                    Circle()
                        .trim(from: 0, to: service.progress)
                        .stroke(modeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: service.progress)
                        .shadow(color: modeColor.opacity(pulseGlow ? 0.5 : 0.1), radius: pulseGlow ? 12 : 4)
                        .animation(DS.Spring.breath, value: pulseGlow)
                }
                
                // Digital Time
                VStack(spacing: 4) {
                    Text(formatTime(service.timeRemaining))
                        .font(.system(size: 32, weight: .light, design: .monospaced))
                        .foregroundStyle(modeColor)
                        .contentTransition(.numericText())
                    
                    if !service.isActive && service.progress < 1.0 {
                        Text("PAUSED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, 8)
            
            // Controls
            HStack(spacing: 24) {
                Button(action: {
                    service.reset()
                    HapticManager.shared.play(.warning)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if service.isActive {
                        service.pause()
                        HapticManager.shared.play(.subtle)
                    } else {
                        service.start()
                        HapticManager.shared.play(.success)
                    }
                }) {
                    Image(systemName: service.isActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 56, height: 56)
                        .background(modeColor)
                        .clipShape(Circle())
                        .shadow(color: modeColor.opacity(0.4), radius: 8, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Session Counter
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(service.completedSessions > 0 ? modeColor.opacity(0.6) : .white.opacity(0.2))
                    if service.completedSessions > 0 {
                        Text("\(service.completedSessions)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(modeColor.opacity(0.5))
                    }
                }
                .frame(width: 40, height: 40)
            }
        }
        .padding(16)
        .onAppear { pulseGlow = service.isActive }
        .onChange(of: service.isActive) { _, active in
            pulseGlow = active
        }
    }
    
    var modeColor: Color {
        switch service.mode {
        case .focus: return DS.Colors.amber
        case .shortBreak: return DS.Colors.cyan
        case .longBreak: return DS.Colors.signalGreen
        }
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
