import Foundation

struct Session: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var cwd: String
    var note: String
    var createdAt: Date

    var folderName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    var folderExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: cwd, isDirectory: &isDir) && isDir.boolValue
    }

    init(id: UUID = UUID(), cwd: String, note: String = "", createdAt: Date = .now) {
        self.id = id
        self.cwd = cwd
        self.note = note
        self.createdAt = createdAt
    }
}

struct SessionLiveState: Equatable, Sendable {
    var branch: String?
    var missingFolder: Bool = false
    var processExited: Bool = false
    var restartToken: Int = 0
    var needsAttention: Bool = false
    var attentionText: String?
}

enum AttentionKind: Sendable {
    case osc
    case bell
    case title
}
