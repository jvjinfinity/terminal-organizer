import Foundation

/// Filters terminal-emulator replies that Grok (and similar TUIs) can
/// mis-read as typed keystrokes in the composer.
///
/// SwiftTerm answers XTVERSION (`CSI > 0 q`) with a DCS payload that always
/// ends in `:`. Grok probes unknown `TERM_PROGRAM` values fire-and-forget,
/// then preserves leftover stdin as composer text — which is why a lone
/// colon appears on launch inside this app but not in Terminal.app.
public enum QueryReplySanitizer {
    /// Returns bytes that should go to the PTY. Empty means drop the write.
    public static func outgoing(_ data: ArraySlice<UInt8>) -> [UInt8] {
        let bytes = Array(data)
        guard isXtversionReply(bytes) else { return bytes }
        return strippedXtversion(bytes)
    }

    /// 7-bit DCS: ESC P > | payload ST(ESC \)
    private static func isXtversionReply(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 6 else { return false }
        return bytes[0] == 0x1b
            && bytes[1] == UInt8(ascii: "P")
            && bytes[2] == UInt8(ascii: ">")
            && bytes[3] == UInt8(ascii: "|")
            && bytes[bytes.count - 2] == 0x1b
            && bytes[bytes.count - 1] == UInt8(ascii: "\\")
    }

    private static func strippedXtversion(_ bytes: [UInt8]) -> [UInt8] {
        var payload = Array(bytes[4..<(bytes.count - 2)])
        while payload.last == UInt8(ascii: ":") {
            payload.removeLast()
        }
        guard !payload.isEmpty else { return [] }
        var out: [UInt8] = [0x1b, UInt8(ascii: "P"), UInt8(ascii: ">"), UInt8(ascii: "|")]
        out.append(contentsOf: payload)
        out.append(0x1b)
        out.append(UInt8(ascii: "\\"))
        return out
    }
}
