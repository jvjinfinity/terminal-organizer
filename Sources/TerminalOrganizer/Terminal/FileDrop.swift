import AppKit
import UniformTypeIdentifiers

enum FileDrop {
    static var pasteboardTypes: [NSPasteboard.PasteboardType] {
        [
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        ]
    }

    static func shellQuote(_ path: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-+/@,~"))
        if !path.isEmpty, path.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return path
        }
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func text(from pasteboard: NSPasteboard) -> String? {
        if let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !files.isEmpty {
            return files.map(shellQuote).joined(separator: " ") + " "
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map { shellQuote($0.path) }.joined(separator: " ") + " "
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return string
        }
        return nil
    }

    static func load(_ providers: [NSItemProvider], send: @escaping (String) -> Void) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        let texts = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) }
        guard !files.isEmpty || !texts.isEmpty else { return false }

        final class Pieces: @unchecked Sendable {
            private let lock = NSLock()
            private var values: [String] = []
            func append(_ value: String) {
                lock.lock()
                values.append(value)
                lock.unlock()
            }
            func snapshot() -> [String] {
                lock.lock()
                defer { lock.unlock() }
                return values
            }
        }

        let group = DispatchGroup()
        let pieces = Pieces()

        for provider in files {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }
                guard let url, url.isFileURL else { return }
                pieces.append(shellQuote(url.path))
            }
        }

        if files.isEmpty {
            for provider in texts {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let text: String?
                    if let value = item as? String {
                        text = value
                    } else if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = nil
                    }
                    guard let text, !text.isEmpty else { return }
                    pieces.append(text)
                }
            }
        }

        group.notify(queue: .main) {
            let values = pieces.snapshot()
            guard !values.isEmpty else { return }
            let joined = values.joined(separator: " ")
            send(joined.hasSuffix(" ") ? joined : joined + " ")
        }
        return true
    }
}
