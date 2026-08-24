import Foundation

@main
enum XtversionCheck {
    static func main() {
        func bytes(_ s: String) -> [UInt8] { Array(s.utf8) }
        func slice(_ s: String) -> ArraySlice<UInt8> { bytes(s)[...] }

        let colon = slice(":")
        precondition(QueryReplySanitizer.outgoing(colon) == bytes(":"), "plain colon must pass through")

        let typed = slice("hello")
        precondition(QueryReplySanitizer.outgoing(typed) == bytes("hello"))

        let dcs = "\u{1b}P>|SwiftTerm 1.0.0:\u{1b}\\"
        let cleaned = QueryReplySanitizer.outgoing(slice(dcs))
        precondition(
            cleaned == bytes("\u{1b}P>|SwiftTerm 1.0.0\u{1b}\\"),
            "XTVERSION trailing colon must be stripped, got \(String(bytes: cleaned, encoding: .utf8) ?? "?")"
        )

        let alreadyClean = "\u{1b}P>|SwiftTerm 1.0.0\u{1b}\\"
        precondition(QueryReplySanitizer.outgoing(slice(alreadyClean)) == bytes(alreadyClean))

        let emptyPayload = "\u{1b}P>|:\u{1b}\\"
        precondition(QueryReplySanitizer.outgoing(slice(emptyPayload)).isEmpty)

        let osc11 = "\u{1b}]11;rgb:0520/0520/0520\u{1b}\\"
        precondition(QueryReplySanitizer.outgoing(slice(osc11)) == bytes(osc11), "OSC 11 must pass through")

        print("XTVERSION sanitizer ok")
    }
}
