import AppKit
import SwiftTerm
import TOSupport

final class OrganizerTerminalView: LocalProcessTerminalView {
    var sessionID: UUID?
    weak var store: SessionStore?
    private var oscTail = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        enableFileDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        enableFileDrop()
    }

    override init(frame: CGRect, font: NSFont? = nil, options: TerminalOptions) {
        super.init(frame: frame, font: font, options: options)
        enableFileDrop()
    }

    private func enableFileDrop() {
        registerForDraggedTypes(FileDrop.pasteboardTypes)
    }

    func insertDroppedText(_ text: String) {
        let payload = text.isEmpty ? text : (text.hasSuffix(" ") ? text : text + " ")
        guard !payload.isEmpty else { return }
        send(source: self, data: Array(payload.utf8)[...])
        window?.makeFirstResponder(self)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrop.text(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileDrop.text(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let text = FileDrop.text(from: sender.draggingPasteboard) else { return false }
        insertDroppedText(text)
        return true
    }

    nonisolated override func bell(source: Terminal) {
        // BEL is used by tab-complete, pagers, and many CLIs. Do not treat it
        // as "Grok needs you" — that is the Grok hook / window-title path.
        super.bell(source: source)
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        if let sessionID {
            store?.clearAttention(sessionID)
        }
        let sanitized = QueryReplySanitizer.outgoing(data)
        guard !sanitized.isEmpty else { return }
        super.send(source: source, data: sanitized[...])
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        ingest(slice)
    }

    /// SwiftTerm's PTY adapter feeds the parser directly, so this is not on
    /// the live output path. Kept for feeds that still go through `dataReceived`.
    func ingest(_ slice: ArraySlice<UInt8>) {
        guard let chunk = String(bytes: slice, encoding: .utf8) else { return }
        let parsed = OSCNotificationScanner.consume(oscTail + chunk)
        oscTail = parsed.remainder
        if oscTail.count > 512 {
            oscTail = String(oscTail.suffix(256))
        }
        guard let sessionID, !parsed.notes.isEmpty else { return }
        for note in parsed.notes {
            store?.sessionAttention(sessionID, title: note.title, body: note.body, kind: .osc)
        }
    }
}
