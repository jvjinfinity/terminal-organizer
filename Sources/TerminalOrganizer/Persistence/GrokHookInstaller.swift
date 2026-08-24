import AppKit
import Foundation

enum GrokHookInstaller {
    static func installIfNeeded() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let hooks = home.appendingPathComponent(".grok/hooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)

        let script = hooks.appendingPathComponent("terminal-organizer-notify.sh")
        let json = hooks.appendingPathComponent("terminal-organizer.json")
        let helper = helperPath()

        let scriptBody = """
        #!/bin/zsh
        set -euo pipefail
        HELPER=\(shellQuote(helper))
        [[ -x "$HELPER" ]] || HELPER="/Applications/Terminal Organizer.app/Contents/MacOS/to-notify"
        [[ -x "$HELPER" ]] || exit 0
        BODY="${GROK_MESSAGE:-Needs attention}"
        EVENT="${GROK_HOOK_EVENT:-Notification}"
        CWD="${GROK_WORKSPACE_ROOT:-$PWD}"
        exec "$HELPER" --cwd "$CWD" --title "Grok" --body "$BODY" --event "$EVENT"
        """
        let jsonBody = """
        {
          "hooks": {
            "Notification": [
              { "hooks": [{ "type": "command", "command": "\(script.path)", "timeout": 10 }] }
            ],
            "Stop": [
              { "hooks": [{ "type": "command", "command": "\(script.path)", "timeout": 10 }] }
            ],
            "StopFailure": [
              { "hooks": [{ "type": "command", "command": "\(script.path)", "timeout": 10 }] }
            ]
          }
        }
        """

        let scriptData = Data(scriptBody.utf8)
        let jsonData = Data(jsonBody.utf8)
        let existingScript = try? Data(contentsOf: script)
        let existingJSON = try? Data(contentsOf: json)
        if existingScript != scriptData {
            try? scriptData.write(to: script, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        }
        if existingJSON != jsonData {
            try? jsonData.write(to: json, options: .atomic)
        }
    }

    private static func helperPath() -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.jimjohnson.TerminalOrganizer") {
            return url.appendingPathComponent("Contents/MacOS/to-notify").path
        }
        return "/Applications/Terminal Organizer.app/Contents/MacOS/to-notify"
    }

    private static func shellQuote(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
