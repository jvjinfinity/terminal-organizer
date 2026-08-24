import Foundation

struct SessionDocument: Codable, Sendable {
    var sessions: [Session]
    var selectedId: UUID?
}

enum SessionPersistence {
    static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = root.appendingPathComponent("Terminal Organizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    static func load() -> SessionDocument {
        let url = fileURL
        guard let data = try? Data(contentsOf: url) else {
            return SessionDocument(sessions: [], selectedId: nil)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SessionDocument.self, from: data)
        } catch {
            return SessionDocument(sessions: [], selectedId: nil)
        }
    }

    static func save(_ document: SessionDocument) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Terminal Organizer: failed to save sessions: \(error)")
        }
    }
}
