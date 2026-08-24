import Foundation

struct OSCNotification {
    var title: String
    var body: String
}

enum OSCNotificationScanner {
    /// Returns completed notifications and the unparsed suffix (an incomplete OSC, if any).
    static func consume(_ text: String) -> (notes: [OSCNotification], remainder: String) {
        var results: [OSCNotification] = []
        var search = text[...]

        while let start = search.range(of: "\u{1b}]") {
            let rest = search[start.upperBound...]
            guard let end = terminator(in: rest) else {
                return (results, String(search[start.lowerBound...]))
            }
            let payload = String(rest[..<end.index])
            search = rest[end.index...].dropFirst(end.skip)
            if let note = decode(payload) {
                results.append(note)
            }
        }
        return (results, "")
    }

    private static func terminator(in rest: Substring) -> (index: String.Index, skip: Int)? {
        var index = rest.startIndex
        while index < rest.endIndex {
            let ch = rest[index]
            if ch == "\u{07}" {
                return (index, 1)
            }
            if ch == "\u{1b}" {
                let next = rest.index(after: index)
                let skip = (next < rest.endIndex && rest[next] == "\\") ? 2 : 1
                return (index, skip)
            }
            index = rest.index(after: index)
        }
        return nil
    }

    private static func decode(_ payload: String) -> OSCNotification? {
        if payload.hasPrefix("777;notify;") {
            let rest = payload.dropFirst("777;notify;".count)
            let parts = rest.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            let title = parts.first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Terminal"
            let body = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            if title.isEmpty && body.isEmpty { return nil }
            return OSCNotification(title: title.isEmpty ? "Terminal" : title, body: body)
        }

        if payload.hasPrefix("9;") && !payload.hasPrefix("9;4;") {
            let body = String(payload.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { return nil }
            return OSCNotification(title: "Terminal", body: body)
        }

        if payload.hasPrefix("99;") {
            let rest = payload.dropFirst(3)
            let body: String
            if let semi = rest.lastIndex(of: ";") {
                body = String(rest[rest.index(after: semi)])
            } else {
                body = String(rest)
            }
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            return OSCNotification(title: "Terminal", body: trimmed)
        }

        return nil
    }
}
