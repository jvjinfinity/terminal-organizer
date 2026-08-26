import Foundation

@main
enum CWDCheck {
    static func main() {
        let a = PathMatch.resolved("/tmp")
        let b = PathMatch.resolved("/private/tmp")
        precondition(a == b, "tmp should resolve equal: \(a) vs \(b)")

        precondition(PathMatch.matchesSession("/Users/foo/proj", eventCwd: "/Users/foo/proj"))
        precondition(PathMatch.matchesSession("/Users/foo/proj/src", eventCwd: "/Users/foo/proj"))
        precondition(!PathMatch.matchesSession("/Users/foo/other", eventCwd: "/Users/foo/proj"))
        precondition(!PathMatch.matchesSession("/Users/foo/proj", eventCwd: ""))
        precondition(PathMatch.matchesExactly("/Users/foo/proj", eventCwd: "/Users/foo/proj"))
        precondition(!PathMatch.matchesExactly("/Users/foo/proj/src", eventCwd: "/Users/foo/proj"))
        print("cwd match ok \(a)")
    }
}
