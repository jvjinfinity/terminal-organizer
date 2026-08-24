import Foundation

@main
enum OSCCheck {
    static func main() {
        let seq = "hello\u{1b}]777;notify;Grok;Waiting for your input\u{07}more"
        let first = OSCNotificationScanner.consume(seq)
        precondition(first.notes.count == 1, "expected 1 note, got \(first.notes.count)")
        precondition(first.notes[0].title == "Grok")
        precondition(first.notes[0].body == "Waiting for your input")
        precondition(first.remainder.isEmpty, "completed OSC must not stay in remainder")

        let again = OSCNotificationScanner.consume(seq + "x")
        precondition(again.notes.count == 1)

        let split = OSCNotificationScanner.consume("\u{1b}]777;notify;Grok;")
        precondition(split.notes.isEmpty)
        precondition(split.remainder.hasPrefix("\u{1b}]"))

        let finished = OSCNotificationScanner.consume(split.remainder + "Done\u{07}")
        precondition(finished.notes.count == 1)
        precondition(finished.notes[0].body == "Done")

        let st = OSCNotificationScanner.consume("\u{1b}]777;notify;Title;Body\u{1b}\\trailing")
        precondition(st.notes.count == 1)
        precondition(st.notes[0].title == "Title")

        print("OSC scanner ok")
    }
}
