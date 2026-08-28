import Foundation

@main
enum GitCheck {
    static func main() {
        let dir = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
        let info = GitStatus.info(in: dir)
        print("branch \(info.branch ?? "NONE")")
        print("repo \(info.repoName ?? "NONE")")
        print("worktree \(info.worktreeName ?? "NONE")")
    }
}
