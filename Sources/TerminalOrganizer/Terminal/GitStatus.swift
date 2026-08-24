import Foundation

enum GitStatus {
    static func branch(in directory: String) -> String? {
        guard let gitDir = gitDirectory(in: directory) else { return nil }
        let headURL = gitDir.appendingPathComponent("HEAD")
        guard let raw = try? String(contentsOf: headURL, encoding: .utf8) else { return nil }
        let head = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "ref: refs/heads/"
        if head.hasPrefix(prefix) {
            let name = String(head.dropFirst(prefix.count))
            return name.isEmpty ? nil : name
        }
        if head.hasPrefix("ref: refs/remotes/") {
            return String(head.dropFirst("ref: ".count))
        }
        if head.count >= 7 {
            return String(head.prefix(7))
        }
        return head.isEmpty ? nil : head
    }

    static func gitDirectory(in directory: String) -> URL? {
        var dir = URL(fileURLWithPath: directory, isDirectory: true).standardizedFileURL
        let fm = FileManager.default
        while true {
            let gitURL = dir.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: gitURL.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    return gitURL
                }
                if let contents = try? String(contentsOf: gitURL, encoding: .utf8) {
                    for line in contents.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("gitdir:") {
                            let path = trimmed.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
                            let resolved: URL
                            if path.hasPrefix("/") {
                                resolved = URL(fileURLWithPath: path, isDirectory: true)
                            } else {
                                resolved = dir.appendingPathComponent(path, isDirectory: true)
                            }
                            return resolved.standardizedFileURL
                        }
                    }
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }
}
