import AppKit
import SwiftUI
import SwiftTerm

struct TerminalHostView: NSViewRepresentable {
    var session: Session
    var store: SessionStore
    var restartToken: Int

    func makeNSView(context: Context) -> TerminalContainerView {
        let container = TerminalContainerView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        let terminal = store.terminals.view(for: session, store: store)
        if terminal.superview !== nsView {
            nsView.subviews.forEach { $0.removeFromSuperview() }
            terminal.translatesAutoresizingMaskIntoConstraints = true
            nsView.addSubview(terminal)
            terminal.frame = nsView.bounds
            terminal.autoresizingMask = [.width, .height]
        }

        nsView.onLayout = { [store, session] in
            store.terminals.startIfNeeded(session: session, view: terminal)
        }
        nsView.layoutSubtreeIfNeeded()
        store.terminals.startIfNeeded(session: session, view: terminal)

        if context.coordinator.lastFocused != session.id
            || context.coordinator.lastToken != restartToken {
            context.coordinator.lastFocused = session.id
            context.coordinator.lastToken = restartToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let window = terminal.window else { return }
                if let first = window.firstResponder {
                    if first is NSTextField { return }
                    if let textView = first as? NSTextView, textView.isFieldEditor { return }
                }
                window.makeFirstResponder(terminal)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastFocused: UUID?
        var lastToken: Int = -1
    }
}

final class TerminalContainerView: NSView {
    var onLayout: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(FileDrop.pasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(FileDrop.pasteboardTypes)
    }

    override func layout() {
        super.layout()
        for sub in subviews {
            sub.frame = bounds
        }
        onLayout?()
    }

    private var terminal: OrganizerTerminalView? {
        subviews.compactMap { $0 as? OrganizerTerminalView }.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        terminal?.draggingEntered(sender) ?? (FileDrop.text(from: sender.draggingPasteboard) == nil ? [] : .copy)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        terminal?.prepareForDragOperation(sender) ?? (FileDrop.text(from: sender.draggingPasteboard) != nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        terminal?.performDragOperation(sender) ?? false
    }
}
