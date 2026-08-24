import Foundation

@main
enum GitCheck {
    static func main() {
        let dir = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
        print(GitStatus.branch(in: dir) ?? "NONE")
    }
}
