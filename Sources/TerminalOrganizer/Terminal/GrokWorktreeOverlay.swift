import Foundation

/// When Grok creates a nested git worktree but leaves the hosting shell in the
/// main checkout, read *that* Grok's session files and overlay the desk on the row.
enum GrokWorktreeOverlay {
    private struct Hit {
        var path: String
        var at: Date
    }

    private static let isoFractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let isoBasic = Date.ISO8601FormatStyle()

    static func worktree(fromSessionDir dir: URL, sessionCwd: String) -> GitStatus.Info? {
        var hits: [Hit] = []
        let hunks = dir.appendingPathComponent("hunk_records.jsonl")
        if FileManager.default.fileExists(atPath: hunks.path) {
            hits.append(contentsOf: hunkHits(from: tail(hunks, maxBytes: 512 * 1024)))
        }
        hits.append(contentsOf: logHits(in: dir.appendingPathComponent("terminal", isDirectory: true), sessionCwd: sessionCwd))
        return firstValid(hits: hits, sessionCwd: sessionCwd)
    }

    static func worktree(fromEvidence text: String, sessionCwd: String) -> GitStatus.Info? {
        var hits = hunkHits(from: text)
        var index = 0
        for path in candidatePaths(in: text, sessionCwd: sessionCwd) {
            hits.append(Hit(path: path, at: Date(timeIntervalSince1970: TimeInterval(index))))
            index += 1
        }
        return firstValid(hits: hits, sessionCwd: sessionCwd)
    }

    private static func firstValid(hits: [Hit], sessionCwd: String) -> GitStatus.Info? {
        let cwd = URL(fileURLWithPath: sessionCwd).standardizedFileURL.path
        let ordered = hits.sorted { $0.at > $1.at }
        var seen = Set<String>()
        for hit in ordered {
            let path = URL(fileURLWithPath: hit.path).standardizedFileURL.path
            if !seen.insert(path).inserted { continue }
            let info = GitStatus.info(in: path)
            guard info.worktreeName != nil else { continue }
            guard GitStatus.sharesRepository(path, sessionCwd) else { continue }
            if let checkout = info.checkoutPath,
               URL(fileURLWithPath: checkout).standardizedFileURL.path == cwd {
                continue
            }
            return info
        }
        return nil
    }

    private static func hunkHits(from text: String) -> [Hit] {
        var hits: [Hit] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.contains("filePath") else { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let path = obj["filePath"] as? String, !path.isEmpty else { continue }
            var date = Date.distantPast
            if let stamp = obj["timestamp"] as? String {
                date = (try? Date(stamp, strategy: isoFractional))
                    ?? (try? Date(stamp, strategy: isoBasic))
                    ?? date
            }
            hits.append(Hit(path: path, at: date))
        }
        return hits
    }

    private static func logHits(in directory: URL, sessionCwd: String) -> [Hit] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let logs = files.filter { $0.pathExtension == "log" }.sorted { lhs, rhs in
            let a = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }.prefix(12)
        var hits: [Hit] = []
        for url in logs {
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            for path in candidatePaths(in: tail(url, maxBytes: 64 * 1024), sessionCwd: sessionCwd) {
                hits.append(Hit(path: path, at: mtime))
            }
        }
        return hits
    }

    static func candidatePaths(in text: String, sessionCwd: String) -> [String] {
        var result: [String] = []
        for marker in ["/.grok/worktrees/", "/.claude/worktrees/"] {
            var search = text.startIndex
            while let range = text.range(of: marker, range: search..<text.endIndex) {
                if let path = worktreePath(in: text, marker: marker, range: range, sessionCwd: sessionCwd) {
                    result.append(path)
                }
                search = range.upperBound
            }
        }
        guard !sessionCwd.isEmpty else { return result }
        for rel in [".grok/worktrees/", ".claude/worktrees/"] {
            var search = text.startIndex
            while let range = text.range(of: rel, range: search..<text.endIndex) {
                if range.lowerBound > text.startIndex, text[text.index(before: range.lowerBound)] == "/" {
                    search = range.upperBound
                    continue
                }
                let restEnd = text[range.upperBound...].firstIndex(where: isPathEnd) ?? text.endIndex
                let first = String(text[range.upperBound..<restEnd]).split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
                if isWorktreeName(first) {
                    result.append(sessionCwd + "/" + rel + first)
                }
                search = range.upperBound
            }
        }
        return result
    }

    private static func worktreePath(
        in text: String,
        marker: String,
        range: Range<String.Index>,
        sessionCwd: String
    ) -> String? {
        let restEnd = text[range.upperBound...].firstIndex(where: isPathEnd) ?? text.endIndex
        let rest = text[range.upperBound..<restEnd]
        let first = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        guard isWorktreeName(first) else { return nil }
        if let root = absolutePrefix(in: text, markerStart: range.lowerBound) {
            return root + marker + first
        }
        if sessionCwd.isEmpty { return nil }
        return sessionCwd + "/" + String(marker.dropFirst()) + first
    }

    private static func absolutePrefix(in text: String, markerStart: String.Index) -> String? {
        var i = markerStart
        while i > text.startIndex {
            let prev = text.index(before: i)
            if isPathEnd(text[prev]) || text[prev] == "=" || text[prev] == ":" || text[prev] == "(" {
                break
            }
            i = prev
        }
        guard i < markerStart, text[i] == "/" else { return nil }
        return String(text[i..<markerStart])
    }

    private static func isPathEnd(_ ch: Character) -> Bool {
        ch.isWhitespace || ch == "\"" || ch == "'" || ch == "<" || ch == ">" || ch == ")" || ch == "," || ch == "]"
    }

    private static func isWorktreeName(_ name: String) -> Bool {
        guard !name.isEmpty, name != "." && name != ".." else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
    }

    static func grokSessionDirectory(fromOpenPath path: String) -> URL? {
        guard let range = path.range(of: "/.grok/sessions/") else { return nil }
        let rest = path[range.upperBound...]
        let parts = rest.split(separator: "/").map(String.init)
        guard parts.count >= 2, isSessionID(parts[1]) else { return nil }
        let dir = String(path[..<range.upperBound]) + parts[0] + "/" + parts[1]
        return URL(fileURLWithPath: dir, isDirectory: true)
    }

    private static func isSessionID(_ value: String) -> Bool {
        let pieces = value.split(separator: "-")
        guard pieces.count == 5 else { return false }
        return value.allSatisfy { $0.isHexDigit || $0 == "-" }
    }

    private static func tail(_ url: URL, maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start: UInt64 = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        let data = (try? handle.readToEnd()) ?? Data()
        var text = String(decoding: data, as: UTF8.self)
        if start > 0, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        return text
    }
}
