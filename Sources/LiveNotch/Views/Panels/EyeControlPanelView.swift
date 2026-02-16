import SwiftUI
import AppKit

struct EyeControlPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var engine = GestureEyeEngine.shared
    
    var body: some View {
        VStack(spacing: 8) {
            PanelHeader(
                icon: "eye.fill",
                iconColor: engine.isActive ? .green : .gray,
                title: L10n.eyeControl,
                trailing: {
                    AnyView(
                        HStack(spacing: 4) {
                            if engine.isActive && engine.faceDetected {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text("Tracking")
                                    .font(DS.Fonts.tinySemi)
                                    .foregroundColor(.green.opacity(0.8))
                            } else if engine.isActive {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 5, height: 5)
                                Text("No face")
                                    .font(DS.Fonts.tiny)
                                    .foregroundColor(.orange.opacity(0.7))
                            }
                        }
                    )
                },
                onClose: { viewModel.isEyeControlVisible = false }
            )
            
            // ── Master Toggle ──
            HStack {
                Image(systemName: engine.isEnabled ? "eye.fill" : "eye.slash")
                    .font(DS.Fonts.body)
                    .foregroundColor(engine.isEnabled ? .green : .gray)
                    .shadow(color: engine.isEnabled ? .green.opacity(0.3) : .clear, radius: 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Eye Gestures")
                        .font(DS.Fonts.bodySemi)
                        .foregroundColor(.white.opacity(0.8))
                    if engine.isActive {
                        Text(engine.isCalibrated ? "Calibrated · \(engine.gestureCount) gestures" : "Calibrating…")
                            .font(DS.Fonts.microMono)
                            .foregroundColor(engine.isCalibrated ? .white.opacity(0.2) : .orange.opacity(0.5))
                    } else {
                        Text("Camera off")
                            .font(DS.Fonts.microMono)
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if engine.isEnabled {
                        engine.isEnabled = false
                        engine.deactivate()
                    } else {
                        engine.isEnabled = true
                        engine.activate()
                    }
                    HapticManager.shared.play(.toggle)
                }) {
                    Text(engine.isEnabled ? "ON" : "OFF")
                        .font(DS.Fonts.tinyMono)
                        .foregroundColor(engine.isEnabled ? .green : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(engine.isEnabled ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .stroke(engine.isEnabled ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            
            // ── Calibration progress (when calibrating) ──
            if engine.isActive && !engine.isCalibrated {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        ProgressView(value: engine.calibrationProgress)
                            .progressViewStyle(.linear)
                            .tint(.cyan)
                        Text("\(Int(engine.calibrationProgress * 100))%")
                            .font(DS.Fonts.microBold)
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                    Text("Look at the camera with both eyes open")
                        .font(DS.Fonts.micro)
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .padding(.horizontal, 14)
            }
            
            // ── Eye Visualizer (when active and calibrated) ──
            if engine.isActive && engine.isCalibrated {
                HStack(spacing: 16) {
                    // Left Eye
                    eyeGraphic(
                        label: "LEFT",
                        ear: engine.visibleLeftEAR,
                        isClosed: engine.visibleIsLeftClosed,
                        color: .cyan
                    )
                    
                    // Center: last gesture or cooldown
                    ZStack {
                        // Cooldown ring
                        if engine.cooldownRemaining > 0 {
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: engine.cooldownRemaining / engine.sensitivity.cooldown)
                                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        VStack(spacing: 2) {
                            if engine.lastGesture != .none {
                                Image(systemName: gestureIcon(engine.lastGesture))
                                    .font(DS.Fonts.h3)
                                    .foregroundColor(gestureColor(engine.lastGesture))
                                    .shadow(color: gestureColor(engine.lastGesture).opacity(0.6), radius: 6)
                                    .transition(.scale.combined(with: .opacity))
                                
                                Text(gestureLabel(engine.lastGesture))
                                    .font(DS.Fonts.microBold)
                                    .foregroundColor(gestureColor(engine.lastGesture).opacity(0.8))
                                    .transition(.opacity)
                            } else if engine.faceDetected {
                                Image(systemName: "face.smiling")
                                    .font(DS.Fonts.h4)
                                    .foregroundColor(.white.opacity(0.15))
                                Text("Ready")
                                    .font(DS.Fonts.micro)
                                    .foregroundColor(.white.opacity(0.2))
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(DS.Fonts.h4)
                                    .foregroundColor(.white.opacity(0.1))
                                Text("Searching")
                                    .font(DS.Fonts.micro)
                                    .foregroundColor(.white.opacity(0.15))
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.lastGesture)
                    
                    // Right Eye
                    eyeGraphic(
                        label: "RIGHT",
                        ear: engine.visibleRightEAR,
                        isClosed: engine.visibleIsRightClosed,
                        color: .purple
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .padding(.horizontal, 14)
            }
            
            // ── Sensitivity Selector ──
            if engine.isActive {
                HStack(spacing: 0) {
                    ForEach(GestureEyeEngine.Sensitivity.allCases, id: \.rawValue) { mode in
                        Button(action: {
                            engine.sensitivity = mode
                            HapticManager.shared.play(.subtle)
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 8, weight: engine.sensitivity == mode ? .heavy : .medium)) // dynamic weight — no token
                                .foregroundColor(engine.sensitivity == mode ? .cyan : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    engine.sensitivity == mode
                                    ? Color.cyan.opacity(0.1)
                                    : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.03))
                .clipShape(Capsule())
                .padding(.horizontal, 14)
            }
            
            // ── Separator ──
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
            
            // ── Gesture Reference (context-aware) ──
            VStack(spacing: 6) {
                // Music mode
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.cyan.opacity(0.6))
                    Text("MUSIC MODE")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.cyan.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                
                gestureRow(icon: "forward.fill", gesture: "Right wink 😉", action: "Next track", color: .cyan)
                gestureRow(icon: "backward.fill", gesture: "Left wink 😉", action: "Prev track", color: .cyan)
                gestureRow(icon: "pause.fill", gesture: "Slow blink 😌", action: "Play / Pause", color: .purple)
                
                // AI mode
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.purple.opacity(0.6))
                    Text("AI MODE")
                        .font(DS.Fonts.microBold)
                        .foregroundColor(.purple.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                
                gestureRow(icon: "sparkles", gesture: "Slow blink 😌", action: "Toggle AI bar", color: .purple)
                gestureRow(icon: "doc.on.clipboard", gesture: "Right wink 😉", action: "Clipboard → Kimi", color: .purple)
                gestureRow(icon: "rectangle.expand.vertical", gesture: "Left wink 😉", action: "Expand / Collapse", color: .indigo)
            }
            .padding(.horizontal, 14)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // ── Eye graphic (stylized eye indicator with EAR bar) ──
    private func eyeGraphic(label: String, ear: Double, isClosed: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            // Eye shape with glow ring
            ZStack {
                // Subtle outer glow
                Ellipse()
                    .fill(color.opacity(isClosed ? 0.15 : 0.05))
                    .frame(width: 40, height: 24)
                    .blur(radius: 4)
                
                // Eye outline
                Ellipse()
                    .stroke(color.opacity(isClosed ? 0.6 : 0.3), lineWidth: 1)
                    .frame(width: 32, height: isClosed ? 4 : 18)
                    .animation(DS.Spring.snap, value: isClosed)
                
                // Iris (when open)
                if !isClosed {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color, color.opacity(0.4)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 5
                            )
                        )
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
                
                // Closed line
                if isClosed {
                    Capsule()
                        .fill(color.opacity(0.5))
                        .frame(width: 24, height: 2)
                }
            }
            .frame(width: 36, height: 22)
            
            // EAR level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                    .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(isClosed ? color : color.opacity(0.4))
                        .frame(width: max(2, geo.size.width * CGFloat(min(ear / 0.5, 1.0))))
                }
            }
            .frame(width: 36, height: 3)
            .animation(DS.Spring.micro, value: ear)
            
            // Label + EAR value
            VStack(spacing: 1) {
                Text(label)
                    .font(DS.Fonts.microBold)
                    .foregroundColor(.white.opacity(0.3))
                Text(String(format: "%.2f", ear))
                    .font(DS.Fonts.microMono)
                    .foregroundColor(isClosed ? color.opacity(0.8) : .white.opacity(0.25))
            }
        }
    }
    
    // ── Gesture info helpers ──
    private func gestureIcon(_ gesture: FaceGesture) -> String {
        switch gesture {
        case .rightWink: return "forward.fill"
        case .leftWink: return "backward.fill"
        case .slowBlink: return "pause.fill"
        case .longBlink: return "brain.head.profile"
        case .handPinch: return "hand.tap.fill"
        case .handSwipeLeft: return "hand.point.left.fill"
        case .handSwipeRight: return "hand.point.right.fill"
        case .none: return "circle"
        }
    }
    
    private func gestureColor(_ gesture: FaceGesture) -> Color {
        switch gesture {
        case .rightWink: return .cyan
        case .leftWink: return .cyan
        case .slowBlink: return .purple
        case .longBlink: return .pink // Naroa color
        case .handPinch: return .orange
        case .handSwipeLeft: return .yellow
        case .handSwipeRight: return .yellow
        case .none: return .white
        }
    }
    
    private func gestureLabel(_ gesture: FaceGesture) -> String {
        switch gesture {
        case .rightWink: return "NEXT ⏭"
        case .leftWink: return "PREV ⏮"
        case .slowBlink: return "PAUSE ⏸"
        case .longBlink: return "SUMMON 🧠"
        case .handPinch: return "TAP ✋"
        case .handSwipeLeft: return "BACK 👈"
        case .handSwipeRight: return "SKIP 👉"
        case .none: return ""
        }
    }
    
    private func gestureRow(icon: String, gesture: String, action: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DS.Fonts.tinyBold)
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)
            
            Text(gesture)
                .font(DS.Fonts.bodySemi)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(action)
                .font(DS.Fonts.small)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
