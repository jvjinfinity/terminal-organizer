import AppKit
import Foundation

enum GrokHookInstaller {
    static func installIfNeeded() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let hooks = home.appendingPathComponent(".grok/hooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)

        let script = hooks.appendingPathComponent("terminal-organizer-notify.sh")
        let python = hooks.appendingPathComponent("terminal-organizer-notify.py")
        let json = hooks.appendingPathComponent("terminal-organizer.json")
        let helper = helperPath()

        let pythonBody = """
        #!/usr/bin/env python3
        import json
        import os
        import sys

        helper = \(pyString(helper))
        if not os.access(helper, os.X_OK):
            helper = "/Applications/Terminal Organizer.app/Contents/MacOS/to-notify"
        if not os.access(helper, os.X_OK):
            sys.exit(0)

        kind = os.environ.get("TO_KIND", "")
        event = os.environ.get("GROK_HOOK_EVENT", "").lower()
        raw = sys.stdin.read()
        try:
            data = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            data = {}
        cwd = (
            data.get("workspaceRoot")
            or data.get("cwd")
            or os.environ.get("GROK_WORKSPACE_ROOT")
            or os.getcwd()
        )
        body = None
        hook_event = event or "notification"
        if kind == "input":
            body = "Needs your input"
            hook_event = "notification"
        elif event == "stop":
            reason = str(data.get("reason") or "")
            sub = data.get("subagentType") or ""
            active = data.get("stopHookActive")
            if reason != "end_turn":
                sys.exit(0)
            if sub:
                sys.exit(0)
            if active is True or str(active).lower() in ("true", "1"):
                sys.exit(0)
            body = "Done"
            hook_event = "stop"
        else:
            sys.exit(0)

        args = [helper, "--cwd", str(cwd), "--title", "Grok", "--body", body, "--event", hook_event]
        pid = os.getppid()
        if pid > 1:
            args.extend(["--pid", str(pid)])
        os.execv(helper, args)
        """

        let scriptBody = """
        #!/bin/zsh
        set -euo pipefail
        exec python3 \(shellQuote(python.path))
        """
        let jsonBody = """
        {
          "hooks": {
            "Notification": [
              {
                "matcher": "permission_prompt",
                "hooks": [{ "type": "command", "command": "\(script.path)", "timeout": 10, "env": { "TO_KIND": "input" } }]
              }
            ],
            "Stop": [
              { "hooks": [{ "type": "command", "command": "\(script.path)", "timeout": 10 }] }
            ]
          }
        }
        """

        writeIfNeeded(python, pythonBody, permissions: 0o755)
        writeIfNeeded(script, scriptBody, permissions: 0o755)
        writeIfNeeded(json, jsonBody, permissions: 0o644)
    }

    private static func writeIfNeeded(_ url: URL, _ text: String, permissions: Int) {
        let data = Data(text.utf8)
        let existing = try? Data(contentsOf: url)
        if existing != data {
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
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

    private static func pyString(_ path: String) -> String {
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
