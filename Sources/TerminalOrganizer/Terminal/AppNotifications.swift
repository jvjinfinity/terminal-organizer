import AppKit
import UserNotifications

enum AppNotifications {
    static let sessionKey = "sessionID"

    @MainActor
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @MainActor
    static func post(sessionID: UUID, folder: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        let cleanTitle = title.isEmpty ? folder : title
        content.title = cleanTitle
        let subtitle = folder
        if subtitle != cleanTitle {
            content.subtitle = subtitle
        }
        content.body = body.isEmpty ? "Needs your attention" : body
        content.sound = .default
        content.userInfo = [sessionKey: sessionID.uuidString]

        let request = UNNotificationRequest(
            identifier: "session-\(sessionID.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    @MainActor
    static func setBadge(_ count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }
}
