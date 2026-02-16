import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 📝 Quick Notes Panel View
// ═══════════════════════════════════════════════════
// Floating scratchpad inside the notch. Multi-note with tabs.

struct QuickNotesPanelView: View {
    @ObservedObject var notes: QuickNotesManager
    @State private var editingTitle = false
    @State private var titleText = ""
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // ── Header with note tabs ──
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.accentBlue)
                
                // Note picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(notes.notes.enumerated()), id: \.element.id) { index, note in
                            Button {
                                notes.selectNote(at: index)
                            } label: {
                                Text(note.title.prefix(12))
                                    .font(DS.Fonts.micro)
                                    .foregroundStyle(
                                        index == notes.activeNoteIndex
                                            ? Color.white
                                            : DS.Colors.textTertiary
                                    )
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        index == notes.activeNoteIndex
                                            ? DS.Colors.accentBlue.opacity(0.3)
                                            : DS.Colors.bgDark.opacity(0.3)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // New note button
                Button {
                    notes.createNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.accentBlue.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                // Word count
                Text("\(notes.wordCount)w")
                    .font(DS.Fonts.microMono)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            
            // ── Editor ──
            if let note = notes.activeNote {
                TextEditor(text: Binding(
                    get: { note.content },
                    set: { notes.updateContent($0) }
                ))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(DS.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(4)
                .background(DS.Colors.bgDark.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(
                            isEditorFocused
                                ? DS.Colors.accentBlue.opacity(0.3)
                                : DS.Colors.strokeFaint,
                            lineWidth: 0.5
                        )
                )
                
                // ── Footer ──
                HStack {
                    Text(note.timeAgo)
                        .font(DS.Fonts.micro)
                        .foregroundStyle(DS.Colors.textTertiary)
                    
                    Spacer()
                    
                    // Delete button (only if >1 note)
                    if notes.notes.count > 1 {
                        Button {
                            notes.deleteNote(at: notes.activeNoteIndex)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 8))
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(DS.Colors.bgDark.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.strokeFaint, lineWidth: 0.5)
        )
    }
}

// ═══════════════════════════════════════════════════
// MARK: - Compact Notes Wing
// ═══════════════════════════════════════════════════

struct NotesWingView: View {
    @ObservedObject var notes: QuickNotesManager
    
    var body: some View {
        if let note = notes.activeNote, !note.content.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "note.text")
                    .font(.system(size: 6))
                    .foregroundStyle(DS.Colors.textTertiary)
                
                Text(note.preview.prefix(15))
                    .font(DS.Fonts.micro)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
