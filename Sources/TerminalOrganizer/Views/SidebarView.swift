import SwiftUI

struct SidebarView: View {
    @Environment(SessionStore.self) private var store
    @FocusState private var filterFocused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button {
                    store.newSessionInCurrentFolder()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("New session in current folder")
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            TextField("Filter", text: $store.filterText)
                .textFieldStyle(.roundedBorder)
                .focused($filterFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: store.focusFilter) { _, want in
                    if want {
                        filterFocused = true
                        store.focusFilter = false
                    }
                }

            Divider()

            if store.sessions.isEmpty {
                emptyList
            } else if store.visibleSessions.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $store.selectedID) {
                    ForEach(store.visibleSessions) { session in
                        SessionRowView(
                            session: session,
                            state: store.live[session.id] ?? SessionLiveState(),
                            isEditing: store.editingNoteID == session.id,
                            onBeginEdit: { store.beginEditNote(session) },
                            onNoteChange: { store.updateNote(session.id, $0) },
                            onEndEdit: { store.finishEditNote() }
                        )
                        .tag(session.id)
                        .draggable(session.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                            store.reorder(dragging: id, onto: session.id)
                            return true
                        }
                        .contextMenu {
                            Button("Edit Note") { store.beginEditNote(session) }
                            Button("Duplicate Session") { store.duplicate(session) }
                                .disabled(!session.folderExists)
                            Button("Restart Shell") { store.restart(session) }
                                .disabled(!session.folderExists)
                            Divider()
                            Button("Move Up") { store.moveSession(session.id, by: -1) }
                            Button("Move Down") { store.moveSession(session.id, by: 1) }
                            Divider()
                            Button("Reveal in Finder") { store.revealInFinder(session) }
                            Button("Copy Path") { store.copyPath(session) }
                            Divider()
                            Button("Clear Note") { store.clearNote(session) }
                                .disabled(session.note.isEmpty)
                            Divider()
                            Button("Close Session", role: .destructive) {
                                store.close(session)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                    .onMove { source, destination in
                        guard store.filterText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.moveSessions(from: source, to: destination)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(.background)
    }

    private var emptyList: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("No sessions")
                .foregroundStyle(.secondary)
            Button("New Session") {
                store.newSessionPickingFolder()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
