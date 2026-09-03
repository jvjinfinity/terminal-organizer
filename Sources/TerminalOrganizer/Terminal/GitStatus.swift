import Foundation

enum GitStatus {
    struct Info: Equatable, Sendable {
        var branch: String? = nil
        var repoName: String? = nil
        var worktreeName: String? = nil
        var checkoutPath: String? = nil
    }

    static func branch(in directory: String) -> String? {
        info(in: directory).branch
    }

    static func info(in directory: String) -> Info {
        guard let located = locate(in: directory) else { return Info() }
        return Info(
            branch: branch(fromGitDir: located.gitDir),
            repoName: located.repoName,
            worktreeName: located.worktreeName,
            checkoutPath: located.checkout.path
        )
    }

    /// True when both paths resolve into the same Git repository (main checkout or a linked worktree).
    static func sharesRepository(_ a: String, _ b: String) -> Bool {
        guard let la = locate(in: a), let lb = locate(in: b) else { return false }
        return commonGitDir(la.gitDir) == commonGitDir(lb.gitDir)
    }

    private struct Location {
        var gitDir: URL
        var checkout: URL
        var repoName: String?
        var worktreeName: String?
    }

    private static func branch(fromGitDir gitDir: URL) -> String? {
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

    private static func locate(in directory: String) -> Location? {
        var dir = URL(fileURLWithPath: directory, isDirectory: true).standardizedFileURL
        let fm = FileManager.default
        while true {
            let gitURL = dir.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: gitURL.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    return Location(gitDir: gitURL, checkout: dir, repoName: dir.lastPathComponent, worktreeName: nil)
                }
                if let gitDir = parseGitFile(gitURL, relativeTo: dir) {
                    return decorate(gitDir: gitDir, checkout: dir)
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    private static func parseGitFile(_ gitURL: URL, relativeTo dir: URL) -> URL? {
        guard let contents = try? String(contentsOf: gitURL, encoding: .utf8) else { return nil }
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
        return nil
    }

    /// Linked worktrees live at `<repo>/.git/worktrees/<name>`. Submodules use `.git/modules/`.
    private static func decorate(gitDir: URL, checkout: URL) -> Location {
        let path = gitDir.path
        if let range = path.range(of: "/.git/worktrees/") {
            let repoRoot = String(path[..<range.lowerBound])
            let repoName = URL(fileURLWithPath: repoRoot).lastPathComponent
            let worktreeName = gitDir.lastPathComponent
            return Location(
                gitDir: gitDir,
                checkout: checkout,
                repoName: repoName.isEmpty ? checkout.lastPathComponent : repoName,
                worktreeName: worktreeName.isEmpty ? nil : worktreeName
            )
        }
        if path.contains("/.git/modules/") {
            return Location(gitDir: gitDir, checkout: checkout, repoName: checkout.lastPathComponent, worktreeName: nil)
        }
        return Location(gitDir: gitDir, checkout: checkout, repoName: checkout.lastPathComponent, worktreeName: nil)
    }

    private static func commonGitDir(_ gitDir: URL) -> String {
        let path = gitDir.path
        if let range = path.range(of: "/.git/worktrees/") {
            return String(path[..<range.lowerBound]) + "/.git"
        }
        return path
    }
}
