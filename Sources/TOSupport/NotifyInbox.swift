import Foundation

public struct NotifyEvent: Codable, Sendable {
    public var cwd: String
    public var title: String
    public var body: String
    public var event: String
    public var pid: Int32?

    public init(cwd: String, title: String, body: String, event: String, pid: Int32? = nil) {
        self.cwd = cwd
        self.title = title
        self.body = body
        self.event = event
        self.pid = pid
    }
}

public enum NotifyInbox {
    public static var directory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = root.appendingPathComponent("Terminal Organizer/inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func write(_ event: NotifyEvent) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        let url = directory.appendingPathComponent("\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    public static func drain() -> [NotifyEvent] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var events: [NotifyEvent] = []
        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            defer { try? fm.removeItem(at: file) }
            guard let data = try? Data(contentsOf: file),
                  let event = try? decoder.decode(NotifyEvent.self, from: data) else { continue }
            events.append(event)
        }
        return events
    }
}

public enum NotifyCLI {
    public static func runIfNeeded() -> Bool {
        let args = CommandLine.arguments
        guard args.contains("--notify") else { return false }
        write(from: args)
        return true
    }

    public static func write(from args: [String]) {
        func value(_ name: String) -> String {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return "" }
            return args[i + 1]
        }
        let pidValue = Int32(value("--pid"))
        let event = NotifyEvent(
            cwd: value("--cwd"),
            title: value("--title").isEmpty ? "Grok" : value("--title"),
            body: value("--body").isEmpty ? "Needs attention" : value("--body"),
            event: value("--event"),
            pid: (pidValue ?? 0) > 1 ? pidValue : nil
        )
        try? NotifyInbox.write(event)
    }
}
