import AppKit
import Foundation
import Observation
import TOSupport

@MainActor
@Observable
final class SessionStore {
    var sessions: [Session] = []
    var selectedID: UUID?
    var live: [UUID: SessionLiveState] = [:]

    let terminals = TerminalRegistry()
    var fontSize: CGFloat = TerminalFont.defaultSize
    var settings = AppSettings()
    var filterText: String = ""
    var editingNoteID: UUID?
    var focusFilter: Bool = false

    var visibleSessions: [Session] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        let needle = query.lowercased()
        return sessions.filter { session in
            if session.folderName.lowercased().contains(needle) { return true }
            if session.cwd.lowercased().contains(needle) { return true }
            if session.note.lowercased().contains(needle) { return true }
            if let branch = live[session.id]?.branch, branch.lowercased().contains(needle) { return true }
            if let repo = live[session.id]?.repoName, repo.lowercased().contains(needle) { return true }
            if let worktree = live[session.id]?.worktreeName, worktree.lowercased().contains(needle) { return true }
            return false
        }
    }

    var windowTitle: String {
        guard let session = selectedSession else { return "Terminal Organizer" }
        let note = session.note.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let clipped = note.count > 40 ? String(note.prefix(37)) + "…" : note
        if clipped.isEmpty { return session.folderName }
        return "\(session.folderName) — \(clipped)"
    }

    private var saveTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var inboxTask: Task<Void, Never>?
    private var lastFolder: String
    private var lastDark: Bool?
    private var lastClose: ContinuousClock.Instant?
    private var lastAttention: [UUID: (at: ContinuousClock.Instant, kind: AttentionKind)] = [:]

    var selectedSession: Session? {
        guard let selectedID else { return nil }
        return sessions.first { $0.id == selectedID }
    }

    init() {
        lastFolder = FileManager.default.homeDirectoryForCurrentUser.path
        let document = SessionPersistence.load()
        sessions = document.sessions
        selectedID = document.selectedId.flatMap { id in
            document.sessions.contains(where: { $0.id == id }) ? id : document.sessions.first?.id
        }
        if selectedID == nil {
            selectedID = sessions.first?.id
        }
        if let cwd = selectedSession?.cwd {
            lastFolder = cwd
        }
        fontSize = TerminalFont.savedSize
        terminals.fontSize = fontSize
        lastFolder = settings.defaultFolder
        if let cwd = selectedSession?.cwd {
            lastFolder = cwd
        }
        refreshLiveState()
        startPolling()
        startInboxWatcher()
        GrokHookInstaller.installIfNeeded()
    }

    func prewarmTerminals() {
        for session in sessions where session.folderExists {
            let view = terminals.view(for: session, store: self)
            if view.frame.width < 8 || view.frame.height < 8 {
                view.frame = CGRect(origin: .zero, size: settings.lastTerminalSize)
            }
            terminals.startIfNeeded(session: session, view: view)
        }
    }

    func newSession() {
        newSessionInCurrentFolder()
    }

    func newSessionInCurrentFolder() {
        let path = selectedSession?.cwd ?? lastFolder
        let start = FileManager.default.fileExists(atPath: path) ? path : settings.defaultFolder
        addSession(at: start)
    }

    func newSessionPickingFolder() {
        guard let folder = pickFolder(startingAt: lastFolder) else { return }
        addSession(at: folder.path)
    }

    func addSession(at path: String, note: String = "") {
        let path = ProcessCWD.standardized(path)
        lastFolder = path
        let session = Session(cwd: path, note: note)
        sessions.append(session)
        live[session.id] = SessionLiveState(missingFolder: !session.folderExists)
        refreshLiveState(for: session.id)
        selectedID = session.id
        persistSoon()
    }

    func closeSelected() {
        let now = ContinuousClock.now
        if let lastClose, now - lastClose < .milliseconds(250) {
            return
        }
        lastClose = now
        guard let selectedID, let session = sessions.first(where: { $0.id == selectedID }) else { return }
        if isBusy(session) && !confirmClose(session) { return }
        close(id: selectedID)
    }

    func close(_ session: Session) {
        if isBusy(session) && !confirmClose(session) { return }
        close(id: session.id)
    }

    func close(id: UUID) {
        terminals.terminate(id)
        live.removeValue(forKey: id)
        lastAttention.removeValue(forKey: id)
        refreshBadge()
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions.remove(at: index)
            if selectedID == id {
                let next = sessions.indices.contains(index)
                    ? sessions[index]
                    : sessions.indices.contains(index - 1) ? sessions[index - 1] : sessions.last
                selectedID = next?.id
            }
        }
        persistSoon()
    }

    func updateNote(_ sessionID: UUID, _ note: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].note = note
        persistSoon()
    }

    func clearNote(_ session: Session) {
        updateNote(session.id, "")
    }

    func updateWorkingDirectory(_ sessionID: UUID, to path: String) {
        let path = ProcessCWD.standardized(path)
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].cwd != path else { return }
        sessions[index].cwd = path
        if selectedID == sessionID {
            lastFolder = path
        }
        refreshLiveState(for: sessionID)
        persistSoon()
    }

    func relocate(_ session: Session) {
        guard let folder = pickFolder(startingAt: session.cwd) else { return }
        terminals.terminate(session.id)
        updateWorkingDirectory(session.id, to: folder.path)
        var state = live[session.id] ?? SessionLiveState()
        state.processExited = false
        state.missingFolder = !FileManager.default.fileExists(atPath: folder.path)
        live[session.id] = state
        refreshLiveState(for: session.id)
        lastFolder = folder.path
        if let current = sessions.first(where: { $0.id == session.id }), current.folderExists {
            let view = terminals.view(for: current, store: self)
            if view.frame.width < 8 || view.frame.height < 8 {
                view.frame = CGRect(origin: .zero, size: settings.lastTerminalSize)
            }
            terminals.startIfNeeded(session: current, view: view)
        }
    }

    func revealParent(_ session: Session) {
        let parent = URL(fileURLWithPath: session.cwd).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            NSWorkspace.shared.activateFileViewerSelecting([parent])
        } else {
            revealInFinder(session)
        }
    }

    func markExited(_ sessionID: UUID) {
        var state = live[sessionID] ?? SessionLiveState()
        state.processExited = true
        live[sessionID] = state
    }

    func selectIndex(_ oneBased: Int) {
        let index = oneBased - 1
        guard sessions.indices.contains(index) else { return }
        selectedID = sessions[index].id
        clearAttention(sessions[index].id)
        persistSoon()
    }

    func revealInFinder(_ session: Session) {
        let url = URL(fileURLWithPath: session.cwd, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyPath(_ session: Session) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.cwd, forType: .string)
    }

    func duplicate(_ session: Session) {
        guard session.folderExists else { return }
        let copy = Session(cwd: session.cwd, note: session.note)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.insert(copy, at: index + 1)
        } else {
            sessions.append(copy)
        }
        live[copy.id] = SessionLiveState(missingFolder: !copy.folderExists)
        refreshLiveState(for: copy.id)
        selectedID = copy.id
        persistSoon()
        let view = terminals.view(for: copy, store: self)
        if view.frame.width < 8 || view.frame.height < 8 {
            view.frame = CGRect(origin: .zero, size: settings.lastTerminalSize)
        }
        terminals.startIfNeeded(session: copy, view: view)
    }

    func duplicateSelected() {
        guard let session = selectedSession else { return }
        duplicate(session)
    }

    func restart(_ session: Session) {
        guard session.folderExists else { return }
        var state = live[session.id] ?? SessionLiveState()
        state.processExited = false
        state.restartToken += 1
        live[session.id] = state
        terminals.restart(session, store: self)
        selectedID = session.id
    }

    func restartSelected() {
        guard let session = selectedSession else { return }
        restart(session)
    }

    func moveSessions(from source: IndexSet, to destination: Int) {
        sessions.move(fromOffsets: source, toOffset: destination)
        persistSoon()
    }

    func adjustFont(by delta: CGFloat) {
        setFontSize(fontSize + delta)
    }

    func resetFont() {
        setFontSize(TerminalFont.defaultSize)
    }

    func sendTypedText(_ text: String, to sessionID: UUID) {
        terminals.sendTypedText(text, to: sessionID)
    }

    func persistSelection() {
        persistSoon()
        if let selectedID {
            clearAttention(selectedID)
        }
        editingNoteID = nil
    }

    func beginEditNote() {
        editingNoteID = selectedID
    }

    func beginEditNote(_ session: Session) {
        selectedID = session.id
        editingNoteID = session.id
    }

    func finishEditNote() {
        editingNoteID = nil
    }

    func chooseDefaultFolder() {
        guard let folder = pickFolder(startingAt: settings.defaultFolder) else { return }
        settings.defaultFolder = folder.path
    }

    func setFontSizePublic(_ size: CGFloat) {
        setFontSize(size)
    }

    func rememberTerminalSize(_ size: NSSize) {
        guard size.width > 80, size.height > 80 else { return }
        settings.lastTerminalSize = size
    }

    func saveWindowFrame() {
        if let frame = NSApp.windows.first(where: { $0.isVisible })?.frame {
            settings.windowFrame = frame
        }
    }

    func restoreWindowFrame() {
        guard let frame = settings.windowFrame else { return }
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else { return }
        window.setFrame(frame, display: true)
    }

    func sessionAttention(_ sessionID: UUID, title: String, body: String, kind: AttentionKind) {
        guard sessions.contains(where: { $0.id == sessionID }) else { return }
        let lookingAtThis = NSApp.isActive && selectedID == sessionID
        if lookingAtThis && !settings.notifyWhenFocused {
            return
        }
        let now = ContinuousClock.now
        if let previous = lastAttention[sessionID] {
            let gap: Duration = kind == .bell ? .seconds(12) : .seconds(3)
            if now - previous.at < gap { return }
        }
        lastAttention[sessionID] = (now, kind)

        var state = live[sessionID] ?? SessionLiveState()
        state.needsAttention = true
        let text = body.isEmpty ? title : body
        state.attentionText = text
        live[sessionID] = state
        refreshBadge()

        if settings.notificationsEnabled && !(lookingAtThis && !settings.notifyWhenFocused) {
            let folder = sessions.first(where: { $0.id == sessionID })?.folderName ?? "Session"
            let note = sessions.first(where: { $0.id == sessionID })?.note ?? ""
            let bodyText = note.isEmpty ? text : "\(note) — \(text)"
            AppNotifications.post(sessionID: sessionID, folder: folder, title: title, body: bodyText)
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    func applyInboxEvent(_ event: NotifyEvent) {
        let ids = inboxTargetIDs(for: event)
        for id in ids {
            sessionAttention(id, title: event.title, body: event.body, kind: .osc)
        }
    }

    private func inboxTargetIDs(for event: NotifyEvent) -> [UUID] {
        if let pid = event.pid, pid > 1, let id = sessionContaining(process: pid) {
            return [id]
        }
        let exact = sessions.filter { PathMatch.matchesExactly($0.cwd, eventCwd: event.cwd) }
        guard !exact.isEmpty else { return [] }
        let home = PathMatch.resolved(FileManager.default.homeDirectoryForCurrentUser.path)
        let eventPath = PathMatch.resolved(event.cwd)
        if eventPath == home || eventPath == "/" { return [] }
        let withGrok = exact.filter { sessionHasGrok($0.id) }
        if withGrok.count == 1 { return [withGrok[0].id] }
        if withGrok.isEmpty, exact.count == 1 { return [exact[0].id] }
        return []
    }

    private func sessionContaining(process pid: Int32) -> UUID? {
        var current = pid
        var seen = Set<Int32>()
        while current > 1, seen.insert(current).inserted {
            if let session = sessions.first(where: { terminals.pid(for: $0.id) == current }) {
                return session.id
            }
            guard let parent = ProcessCWD.parent(of: current) else { break }
            current = parent
        }
        return nil
    }

    private func sessionHasGrok(_ sessionID: UUID) -> Bool {
        guard let pid = terminals.pid(for: sessionID) else { return false }
        let proc = Process()
        let out = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-P", String(pid), "-f", "grok"]
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return false
        }
        return proc.terminationStatus == 0
    }

    func reorder(dragging id: UUID, onto target: UUID) {
        guard filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard id != target,
              let from = sessions.firstIndex(where: { $0.id == id }),
              sessions.contains(where: { $0.id == target }) else { return }
        let item = sessions.remove(at: from)
        guard let to = sessions.firstIndex(where: { $0.id == target }) else {
            sessions.append(item)
            persistSoon()
            return
        }
        sessions.insert(item, at: to)
        persistSoon()
    }

    func moveSession(_ id: UUID, by delta: Int) {
        selectedID = id
        moveSelected(by: delta)
    }

    func moveSelected(by delta: Int) {
        guard filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let id = selectedID, let from = sessions.firstIndex(where: { $0.id == id }) else { return }
        let to = from + delta
        guard sessions.indices.contains(to) else { return }
        sessions.swapAt(from, to)
        persistSoon()
    }

    func clearAttention(_ sessionID: UUID) {
        guard var state = live[sessionID], state.needsAttention else { return }
        state.needsAttention = false
        live[sessionID] = state
        refreshBadge()
    }

    func selectSessionFromNotification(_ sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else { return }
        selectedID = sessionID
        clearAttention(sessionID)
        persistSoon()
        NSApp.activate()
    }

    func shutdown() {
        saveWindowFrame()
        persistNow()
        pollTask?.cancel()
        inboxTask?.cancel()
        terminals.terminateAll()
        AppNotifications.setBadge(0)
    }

    func refreshLiveState() {
        for session in sessions {
            refreshLiveState(for: session.id)
        }
    }

    private func refreshLiveState(for sessionID: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return }
        var state = live[sessionID] ?? SessionLiveState()
        state.missingFolder = !session.folderExists
        let git = session.folderExists ? GitStatus.info(in: session.cwd) : GitStatus.Info()
        if git.worktreeName == nil,
           session.folderExists,
           let pid = terminals.pid(for: sessionID),
           let overlay = GrokWorktreeOverlay.info(shellPid: pid, sessionCwd: session.cwd) {
            state.branch = overlay.branch
            state.repoName = overlay.repoName ?? git.repoName
            state.worktreeName = overlay.worktreeName
        } else {
            state.branch = git.branch
            state.repoName = git.repoName
            state.worktreeName = git.worktreeName
        }
        guard live[sessionID] != state else { return }
        live[sessionID] = state
    }

    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                self?.pollWorkingDirectories()
            }
        }
    }

    private func startInboxWatcher() {
        inboxTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let events = self?.flatMapInbox() {
                    for event in events {
                        self?.applyInboxEvent(event)
                    }
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    private func flatMapInbox() -> [NotifyEvent]? {
        let events = NotifyInbox.drain()
        return events.isEmpty ? nil : events
    }

    private func isBusy(_ session: Session) -> Bool {
        guard let pid = terminals.pid(for: session.id) else { return false }
        let proc = Process()
        let out = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-P", String(pid)]
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return false
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return !data.isEmpty
    }

    private func confirmClose(_ session: Session) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close “\(session.folderName)”?"
        alert.informativeText = "A process is still running in this session."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func pollWorkingDirectories() {
        for session in sessions {
            let exited = live[session.id]?.processExited == true
            if !exited, let pid = terminals.pid(for: session.id), let path = ProcessCWD.path(for: pid) {
                updateWorkingDirectory(session.id, to: path)
            }
            // Branch can change without cd (git checkout / switch in place).
            refreshLiveState(for: session.id)
        }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if lastDark != dark {
            lastDark = dark
            terminals.applyAppearanceToAll()
        }
    }

    private func refreshBadge() {
        let count = live.values.filter(\.needsAttention).count
        AppNotifications.setBadge(count)
    }

    private func setFontSize(_ size: CGFloat) {
        let clamped = min(TerminalFont.maxSize, max(TerminalFont.minSize, size.rounded()))
        guard clamped != fontSize else { return }
        fontSize = clamped
        TerminalFont.savedSize = clamped
        terminals.applyFont(clamped)
    }

    private func persistSoon() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        SessionPersistence.save(SessionDocument(sessions: sessions, selectedId: selectedID))
    }

    private func pickFolder(startingAt path: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.prompt = "Open"
        panel.message = "Choose a folder for this terminal session"
        let start = FileManager.default.fileExists(atPath: path) ? path : FileManager.default.homeDirectoryForCurrentUser.path
        panel.directoryURL = URL(fileURLWithPath: start, isDirectory: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
