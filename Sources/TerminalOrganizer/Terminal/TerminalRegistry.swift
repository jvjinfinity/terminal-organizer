import AppKit
import SwiftTerm

@MainActor
final class TerminalRegistry {
    private var views: [UUID: LocalProcessTerminalView] = [:]
    private var started: Set<UUID> = []
    private var coordinators: [UUID: TerminalSessionCoordinator] = [:]
    var fontSize: CGFloat = TerminalFont.defaultSize

    func view(for session: Session, store: SessionStore) -> LocalProcessTerminalView {
        if let existing = views[session.id] {
            return existing
        }

        let view = OrganizerTerminalView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.optionAsMetaKey = false
        view.bellStyle = .none
        view.sessionID = session.id
        view.store = store
        applyAppearance(to: view)

        let coordinator = TerminalSessionCoordinator(sessionID: session.id, store: store)
        view.processDelegate = coordinator
        coordinators[session.id] = coordinator
        views[session.id] = view
        return view
    }

    func startIfNeeded(session: Session, view: LocalProcessTerminalView) {
        guard !started.contains(session.id) else { return }
        guard session.folderExists else { return }
        guard view.bounds.width > 8, view.bounds.height > 8 else { return }

        applyAppearance(to: view)
        view.startProcess(
            executable: DefaultShell.path,
            args: [],
            environment: environment(for: session),
            execName: DefaultShell.loginName,
            currentDirectory: session.cwd
        )
        started.insert(session.id)
    }

    func sendTypedText(_ text: String, to sessionID: UUID) {
        guard let view = views[sessionID] as? OrganizerTerminalView else {
            guard let view = views[sessionID] else { return }
            view.send(source: view, data: Array(text.utf8)[...])
            return
        }
        view.insertDroppedText(text)
    }

    func pid(for id: UUID) -> Int32? {
        let pid = views[id]?.process?.shellPid ?? 0
        return pid > 0 ? pid : nil
    }

    func terminate(_ id: UUID) {
        if let view = views[id] {
            view.terminate()
            view.removeFromSuperview()
        }
        views.removeValue(forKey: id)
        coordinators.removeValue(forKey: id)
        started.remove(id)
    }

    func terminateAll() {
        for id in Array(views.keys) {
            terminate(id)
        }
    }

    func applyAppearanceToAll() {
        for view in views.values {
            applyAppearance(to: view)
        }
    }

    func applyFont(_ size: CGFloat) {
        fontSize = size
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        for view in views.values {
            view.font = font
        }
    }

    func restart(_ session: Session, store: SessionStore) {
        terminate(session.id)
        guard session.folderExists else { return }
        let view = view(for: session, store: store)
        if view.frame.width < 8 || view.frame.height < 8 {
            view.frame = CGRect(x: 0, y: 0, width: 880, height: 560)
        }
        startIfNeeded(session: session, view: view)
    }

    private func applyAppearance(to view: LocalProcessTerminalView) {
        // Terminal.app "Pro"-style dark screen in both appearances.
        view.nativeForegroundColor = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.93, alpha: 1)
        view.nativeBackgroundColor = NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        view.caretColor = NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.55, alpha: 1)
    }

    private func environment(for session: Session) -> [String] {
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.removeAll {
            $0.hasPrefix("TERM_PROGRAM=")
                || $0.hasPrefix("PWD=")
                || $0.hasPrefix("GROK_APPEARANCE=")
                || $0.hasPrefix("LC_GROK_APPEARANCE=")
                || $0.hasPrefix("COLORFGBG=")
        }
        env.append("TERM_PROGRAM=TerminalOrganizer")
        env.append("PWD=\(session.cwd)")
        // Always-dark screen (Pro-style). Stops Grok's startup OSC 11 probe,
        // whose `rgb:` reply can otherwise leak into the composer.
        env.append("GROK_APPEARANCE=dark")
        env.append("LC_GROK_APPEARANCE=dark")
        env.append("COLORFGBG=15;0")
        return env
    }
}

@MainActor
final class TerminalSessionCoordinator: LocalProcessTerminalViewDelegate {
    let sessionID: UUID
    weak var store: SessionStore?

    init(sessionID: UUID, store: SessionStore) {
        self.sessionID = sessionID
        self.store = store
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let lower = title.lowercased()
        // Do not match "waiting for response" — Grok uses that while it is busy.
        if lower.contains("action required")
            || lower.contains("needs your input")
            || lower.contains("needs input")
            || lower.contains("awaiting your input") {
            store?.sessionAttention(sessionID, title: "Terminal", body: title, kind: .title)
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let path = ProcessCWD.parseOSC7(directory) else { return }
        store?.updateWorkingDirectory(sessionID, to: path)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        store?.markExited(sessionID)
    }
}
