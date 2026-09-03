import Foundation

@main
enum VersionCheck {
    static func main() {
        let cases = [
            ("1.3", "11", "1.3.11"),
            ("1.3.11", "11", "1.3.11"),
        ]
        for (short, build, want) in cases {
            let got = AppVersion.display(short: short, build: build)
            guard got == want else {
                fputs("AppVersion.display(\(short), \(build)) => \(got), expected \(want)\n", stderr)
                exit(1)
            }
        }
        print("version display ok")
    }
}
