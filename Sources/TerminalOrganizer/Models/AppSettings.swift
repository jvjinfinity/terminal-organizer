import AppKit
import Foundation

@MainActor
@Observable
final class AppSettings {
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var notifyWhenFocused: Bool {
        didSet { defaults.set(notifyWhenFocused, forKey: Keys.notifyWhenFocused) }
    }
    var defaultFolder: String {
        didSet { defaults.set(defaultFolder, forKey: Keys.defaultFolder) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let notifyWhenFocused = "notifyWhenFocused"
        static let defaultFolder = "defaultFolder"
        static let windowFrame = "windowFrame"
        static let terminalWidth = "terminalWidth"
        static let terminalHeight = "terminalHeight"
    }

    init() {
        let d = UserDefaults.standard
        notificationsEnabled = d.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        notifyWhenFocused = d.object(forKey: Keys.notifyWhenFocused) as? Bool ?? false
        defaultFolder = d.string(forKey: Keys.defaultFolder)
            ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    var windowFrame: NSRect? {
        get {
            guard let s = defaults.string(forKey: Keys.windowFrame) else { return nil }
            let p = s.split(separator: ",").compactMap { Double($0) }
            guard p.count == 4 else { return nil }
            return NSRect(x: p[0], y: p[1], width: p[2], height: p[3])
        }
        set {
            guard let f = newValue else { return }
            defaults.set("\(f.origin.x),\(f.origin.y),\(f.size.width),\(f.size.height)", forKey: Keys.windowFrame)
        }
    }

    var lastTerminalSize: NSSize {
        get {
            let w = defaults.double(forKey: Keys.terminalWidth)
            let h = defaults.double(forKey: Keys.terminalHeight)
            if w < 80 || h < 80 { return NSSize(width: 900, height: 600) }
            return NSSize(width: w, height: h)
        }
        set {
            defaults.set(Double(newValue.width), forKey: Keys.terminalWidth)
            defaults.set(Double(newValue.height), forKey: Keys.terminalHeight)
        }
    }
}
