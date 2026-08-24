import SwiftUI

struct SessionRowView: View {
    let session: Session
    let state: SessionLiveState
    var isEditing: Bool
    var onBeginEdit: () -> Void
    var onNoteChange: (String) -> Void
    var onEndEdit: () -> Void

    @State private var draft: String = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("Drag onto another row to reorder")
                if state.needsAttention {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                }
                Text(session.folderName)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if let branch = state.branch {
                    Text(branch)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if isEditing {
                TextField("what are you doing?", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .lineLimit(1...3)
                    .focused($noteFocused)
                    .onAppear {
                        draft = session.note
                        DispatchQueue.main.async { noteFocused = true }
                    }
                    .onSubmit {
                        onNoteChange(draft)
                        onEndEdit()
                    }
                    .onChange(of: draft) { _, newValue in
                        onNoteChange(newValue)
                    }
            } else if session.note.isEmpty {
                Text("add a note")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .onTapGesture(perform: onBeginEdit)
            } else {
                Text(session.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .onTapGesture(perform: onBeginEdit)
            }

            if state.missingFolder {
                Text("folder missing")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if state.processExited {
                Text("shell exited")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if state.needsAttention, let text = state.attentionText, !text.isEmpty {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .onChange(of: isEditing) { _, editing in
            if editing {
                draft = session.note
                DispatchQueue.main.async { noteFocused = true }
            }
        }
    }
}
