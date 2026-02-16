import SwiftUI

struct MindflowPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var brainDump: BrainDumpManager
    
    @State private var brainInput: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            PanelHeader(
                icon: "wind",
                iconColor: .cyan,
                title: L10n.mindflow,
                trailing: {
                    HStack(spacing: 6) {
                        if brainDump.activeCount > 0 {
                            Text("\(brainDump.activeCount)")
                                .font(DS.Fonts.tinyBold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        brainDump.urgentCount > 0 ?
                                            Color.red.opacity(0.6) :
                                            Color.cyan.opacity(0.4)
                                    )
                                )
                        }
                        
                        if brainDump.items.contains(where: { $0.isDone }) {
                            Button(action: { 
                                brainDump.clearDone()
                                HapticManager.shared.play(.toggle)
                            }) {
                                Text("Clear ✓")
                                    .font(DS.Fonts.tinySemi)
                                    .foregroundColor(.green.opacity(0.6))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                },
                onClose: { viewModel.isBrainDumpVisible = false }
            )
            
            // Input field
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Fonts.h4)
                    .foregroundColor(.cyan.opacity(0.6))
                
                TextField("What's on your mind...", text: $brainInput)
                    .textFieldStyle(.plain)
                    .font(DS.Fonts.label)
                    .foregroundColor(.white)
                    .onSubmit {
                        if !brainInput.isEmpty {
                            brainDump.addItem(brainInput)
                            brainInput = ""
                            HapticManager.shared.play(.subtle)
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.cyan.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 14)
            
            // Items list (sorted: urgent first, then by priority, then newest)
            if brainDump.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "brain.filled.head.profile")
                        .font(DS.Fonts.h2)
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan.opacity(0.3), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("Your mind is clear")
                        .font(DS.Fonts.bodyRound)
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(brainDump.sortedItems) { item in
                            brainItemRow(item)
                        }
                    }
                }
                .frame(maxHeight: 140)
                .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    func brainItemRow(_ item: BrainDumpManager.BrainItem) -> some View {
        HStack(spacing: 8) {
            Button(action: { 
                brainDump.toggleDone(item)
                HapticManager.shared.play(.dryTick)
            }) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(DS.Fonts.title)
                    .foregroundColor(item.isDone ? .green.opacity(0.7) : .white.opacity(0.2))
            }
            .buttonStyle(.plain)
            
            Circle()
                .fill(categoryColor(item.category))
                .frame(width: 5, height: 5)
                .shadow(color: categoryColor(item.category).opacity(0.5), radius: 2)
            
            Text(item.category.emoji)
                .font(DS.Fonts.tiny)
                .grayscale(1.0)
                .opacity(0.8)
            
            Text(item.text)
                .font(.system(size: 10.5, weight: item.priority == 1 ? .bold : .regular))
                .foregroundColor(item.isDone ? .white.opacity(0.2) : .white.opacity(0.8))
                .strikethrough(item.isDone)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.timeAgo)
                .font(DS.Fonts.tiny)
                .foregroundColor(.white.opacity(0.2))
            
            Button(action: { 
                brainDump.removeItem(item)
                HapticManager.shared.play(.warning)
            }) {
                Image(systemName: "xmark")
                .font(DS.Fonts.microBold)
                .foregroundColor(.white.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            item.priority == 1 ? Color.red.opacity(0.06) : Color.white.opacity(0.02)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
        )
    }
    
    func categoryColor(_ category: BrainDumpManager.Category) -> Color {
        switch category {
        case .work: return .blue
        case .dev: return .cyan
        case .personal: return .green
        case .health: return .orange
        case .idea: return .purple
        case .reminder: return .yellow
        case .shopping: return .teal
        case .urgent: return .red
        }
    }
}
