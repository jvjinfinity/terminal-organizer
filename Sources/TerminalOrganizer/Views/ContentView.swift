import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(SessionStore.self) private var store
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 248, max: 360)
        } detail: {
            detail
        }
        .navigationTitle(store.windowTitle)
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            store.prewarmTerminals()
            DispatchQueue.main.async {
                store.restoreWindowFrame()
            }
        }
        .onChange(of: store.selectedID) { _, _ in
            store.persistSelection()
        }
    }

    @ViewBuilder
    private var detail: some View {
        if store.sessions.isEmpty {
            EmptyDetailView(kind: .noSessions) {
                store.newSessionPickingFolder()
            }
        } else if let session = store.selectedSession {
            let state = store.live[session.id] ?? SessionLiveState()
            if state.missingFolder {
                MissingFolderView(session: session)
            } else {
                VStack(spacing: 0) {
                    if state.processExited {
                        HStack(spacing: 8) {
                            Text("Shell exited")
                                .font(.callout)
                            Spacer()
                            Button("Restart") { store.restart(session) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                    TerminalHostView(
                        session: session,
                        store: store,
                        restartToken: state.restartToken
                    )
                    .background(Color(nsColor: .black))
                    .background(SizeReporter { store.rememberTerminalSize($0) })
                    .onDrop(of: [.fileURL, .utf8PlainText], isTargeted: nil) { providers in
                        FileDrop.load(providers) { text in
                            store.sendTypedText(text, to: session.id)
                        }
                    }
                }
            }
        } else {
            EmptyDetailView(kind: .noSelection) {
                store.newSessionPickingFolder()
            }
        }
    }
}

private enum EmptyKind {
    case noSessions
    case noSelection
}

private struct EmptyDetailView: View {
    let kind: EmptyKind
    var onNew: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "apple.terminal")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            Text(kind == .noSessions ? "No Sessions" : "Select a Session")
                .font(.title2)

            Text(
                kind == .noSessions
                    ? "Open a folder to start a terminal. Each session keeps its own shell, git branch, and a short note on the left."
                    : "Choose a session in the sidebar, or open a new one."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)

            Button("New Session", action: onNew)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct MissingFolderView: View {
    @Environment(SessionStore.self) private var store
    let session: Session

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("This folder is gone")
                .font(.title2)
            Text(session.cwd)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Button("Choose Folder") { store.relocate(session) }
                    .buttonStyle(.borderedProminent)
                Button("Open Parent") { store.revealParent(session) }
                Button("Close Session", role: .destructive) { store.close(session) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct SizeReporter: View {
    var onChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { onChange(geo.size) }
                .onChange(of: geo.size) { _, size in
                    onChange(size)
                }
        }
    }
}
