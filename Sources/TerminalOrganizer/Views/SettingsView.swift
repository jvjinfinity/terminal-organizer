import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        Form {
            Section("Sessions") {
                LabeledContent("Default folder") {
                    HStack {
                        Text(settings.defaultFolder)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 280, alignment: .trailing)
                        Button("Choose…") { store.chooseDefaultFolder() }
                    }
                }
            }
            Section("Notifications") {
                Toggle("Mac notifications when a session needs you", isOn: $settings.notificationsEnabled)
                Toggle("Notify even when that session is focused", isOn: $settings.notifyWhenFocused)
                    .disabled(!settings.notificationsEnabled)
            }
            Section("Terminal") {
                Stepper(
                    "Font size: \(Int(store.fontSize))",
                    value: Binding(
                        get: { store.fontSize },
                        set: { store.setFontSizePublic($0) }
                    ),
                    in: TerminalFont.minSize...TerminalFont.maxSize
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 320)
        .padding()
    }
}
