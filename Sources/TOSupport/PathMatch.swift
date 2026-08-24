import Foundation

public enum PathMatch {
    public static func resolved(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    /// True when the session is the event workspace, or a directory inside it.
    public static func matchesSession(_ sessionCwd: String, eventCwd: String) -> Bool {
        let session = resolved(sessionCwd)
        let event = resolved(eventCwd)
        guard !session.isEmpty, !event.isEmpty else { return false }
        if session == event { return true }
        return session.hasPrefix(event + "/")
    }
}
