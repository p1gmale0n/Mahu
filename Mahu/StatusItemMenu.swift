import AppKit

enum StatusItemMenuAction {
    case toggleRemindersPauseState
    case showSettings
    case quit
}

struct StatusItemMenuItemDescriptor {
    let title: String
    let action: StatusItemMenuAction
    let keyEquivalent: String
    let isEnabled: Bool
}

enum StatusItemMenu {
    static let pauseRemindersTitle = "Pause Reminders"
    static let resumeRemindersTitle = "Resume Reminders"
    static let settingsTitle = "Settings…"
    static let quitTitle = "Quit"

    static func itemDescriptors(
        remindersPaused: Bool,
        reminderActionsAreConfigured: Bool,
        settingsActionIsConfigured: Bool
    ) -> [StatusItemMenuItemDescriptor] {
        [
            StatusItemMenuItemDescriptor(
                title: remindersPaused ? resumeRemindersTitle : pauseRemindersTitle,
                action: .toggleRemindersPauseState,
                keyEquivalent: "",
                isEnabled: reminderActionsAreConfigured
            ),
            StatusItemMenuItemDescriptor(
                title: settingsTitle,
                action: .showSettings,
                keyEquivalent: "",
                isEnabled: settingsActionIsConfigured
            ),
            StatusItemMenuItemDescriptor(
                title: quitTitle,
                action: .quit,
                keyEquivalent: "q",
                isEnabled: true
            )
        ]
    }
}
