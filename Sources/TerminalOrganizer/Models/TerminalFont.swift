import Foundation

enum TerminalFont {
    static let defaultSize: CGFloat = 13
    static let minSize: CGFloat = 9
    static let maxSize: CGFloat = 28
    private static let key = "terminalFontSize"

    static var savedSize: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: key)
            if value == 0 { return defaultSize }
            return min(maxSize, max(minSize, value))
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: key)
        }
    }
}
