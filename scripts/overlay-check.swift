import Foundation

@main
enum OverlayCheck {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { usage() }
        switch command {
        case "open-path":
            guard args.count >= 2 else { usage() }
            if let dir = GrokWorktreeOverlay.grokSessionDirectory(fromOpenPath: args[1]) {
                print(dir.path)
            } else {
                print("NONE")
            }
        case "evidence":
            guard args.count >= 3 else { usage() }
            printInfo(GrokWorktreeOverlay.worktree(fromEvidence: read(args[2]), sessionCwd: args[1]))
        case "session-dir":
            guard args.count >= 3 else { usage() }
            let dir = URL(fileURLWithPath: args[2], isDirectory: true)
            printInfo(GrokWorktreeOverlay.worktree(fromSessionDir: dir, sessionCwd: args[1]))
        default:
            guard args.count >= 2 else { usage() }
            let cwd = args[0]
            let evidence = args[1]
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: evidence, isDirectory: &isDir), isDir.boolValue {
                printInfo(GrokWorktreeOverlay.worktree(
                    fromSessionDir: URL(fileURLWithPath: evidence, isDirectory: true),
                    sessionCwd: cwd
                ))
            } else {
                printInfo(GrokWorktreeOverlay.worktree(fromEvidence: read(evidence), sessionCwd: cwd))
            }
        }
    }

    private static func printInfo(_ info: GitStatus.Info?) {
        print("branch \(info?.branch ?? "NONE")")
        print("repo \(info?.repoName ?? "NONE")")
        print("worktree \(info?.worktreeName ?? "NONE")")
    }

    private static func read(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    private static func usage() -> Never {
        fputs("usage: overlay-check <cwd> <sessionDir|file>\n", stderr)
        fputs("       overlay-check session-dir <cwd> <dir>\n", stderr)
        fputs("       overlay-check evidence <cwd> <file>\n", stderr)
        fputs("       overlay-check open-path <path>\n", stderr)
        exit(2)
    }
}
