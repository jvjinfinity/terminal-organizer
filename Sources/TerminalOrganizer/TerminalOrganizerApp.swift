import AppKit
import Darwin
import SwiftUI
import TOSupport
import UserNotifications

@main
struct TerminalOrganizerApp: App {
    @State private var store: SessionStore?
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if NotifyCLI.runIfNeeded() {
            Darwin.exit(0)
        }
    }

    var body: some Scene {
        Window("Terminal Organizer", id: "main") {
            Group {
                if let store {
                    ContentView()
                        .environment(store)
                        .onAppear {
                            appDelegate.attach(store)
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                            store.shutdown()
                        }
                } else {
                    Color.clear
                        .onAppear {
                            let created = SessionStore()
                            store = created
                            appDelegate.attach(created)
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate()
                        }
                }
            }
            .frame(minWidth: 880, minHeight: 540)
        }
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    store?.newSessionInCurrentFolder()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Session…") {
                    store?.newSessionPickingFolder()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Close Session") {
                    store?.closeSelected()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(store?.selectedSession == nil)
            }

            CommandGroup(after: .newItem) {
                Button("Duplicate Session") {
                    store?.duplicateSelected()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(store?.selectedSession == nil)

                Button("Restart Shell") {
                    store?.restartSelected()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store?.selectedSession == nil)
            }

            CommandMenu("Session") {
                Button("Edit Note") {
                    store?.beginEditNote()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(store?.selectedSession == nil)

                Button("Filter Sessions") {
                    store?.focusFilter = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Move Session Up") {
                    store?.moveSelected(by: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(store?.selectedSession == nil)

                Button("Move Session Down") {
                    store?.moveSelected(by: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(store?.selectedSession == nil)

                Divider()

                Button("Reveal in Finder") {
                    if let session = store?.selectedSession {
                        store?.revealInFinder(session)
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store?.selectedSession == nil)

                Button("Copy Path") {
                    if let session = store?.selectedSession {
                        store?.copyPath(session)
                    }
                }
                .disabled(store?.selectedSession == nil)

                Divider()

                ForEach(1...9, id: \.self) { index in
                    Button("Session \(index)") {
                        store?.selectIndex(index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                    .disabled((store?.sessions.count ?? 0) < index)
                }
            }

            CommandMenu("View") {
                Button("Larger Font") {
                    store?.adjustFont(by: 1)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Larger Font") {
                    store?.adjustFont(by: 1)
                }
                .keyboardShortcut("=", modifiers: .command)
                .hidden()

                Button("Smaller Font") {
                    store?.adjustFont(by: -1)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    store?.resetFont()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
        }

        Settings {
            if let store {
                SettingsView()
                    .environment(store)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: SessionStore?
    private var keyMonitor: Any?
    private var activity: NSObjectProtocol?
    private let notificationRouter = NotificationRouter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("live terminal sessions")
        ProcessInfo.processInfo.disableSuddenTermination()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [
                .userInitiatedAllowingIdleSystemSleep,
                .suddenTerminationDisabled,
            ],
            reason: "Interactive terminal sessions"
        )
        UNUserNotificationCenter.current().delegate = notificationRouter
        AppNotifications.requestPermission()
        installKeyMonitor()
    }

    func attach(_ store: SessionStore) {
        self.store = store
        notificationRouter.store = store
        installKeyMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.shutdown()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags == .command, event.charactersIgnoringModifiers?.lowercased() == "w" else {
            return event
        }
        guard let store, store.selectedSession != nil else {
            return event
        }
        store.closeSelected()
        return nil
    }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var store: SessionStore?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo[AppNotifications.sessionKey] as? String
        completionHandler()
        guard let raw, let id = UUID(uuidString: raw) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.store?.selectSessionFromNotification(id)
        }
    }
}
