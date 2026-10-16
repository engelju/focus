import AppKit
import UserNotifications

/// Desktop notifications when a segment ends, with Start / Skip actions.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let settings = AppSettings.shared
    private var authorized = false

    private enum Category {
        static let flowEnded = "flowEnded"
        static let breakEnded = "breakEnded"
        static let appBlocked = "appBlocked"
    }

    private var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter requires a bundled, signed app.
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    func bootstrap() {
        guard let center else { return }
        center.delegate = self

        let start = UNNotificationAction(identifier: "start", title: "Start", options: [.foreground])
        let skip = UNNotificationAction(identifier: "skip", title: "Skip", options: [])
        let open = UNNotificationAction(identifier: "open", title: "Open", options: [.foreground])

        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.flowEnded, actions: [start, skip],
                                   intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Category.breakEnded, actions: [start, skip],
                                   intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Category.appBlocked, actions: [open],
                                   intentIdentifiers: [], options: []),
        ])

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    /// Posts the notification for a finished segment.
    func phaseCompleted(_ finished: Phase, next: Phase) {
        if finished == .focus {
            SoundService.shared.playFlowEndSound()
            post(title: NotificationCopy.flowTitles.randomElement() ?? "Session complete",
                 body: NotificationCopy.flowBodies.randomElement() ?? "Time for a break.",
                 category: Category.flowEnded)
        } else {
            SoundService.shared.playBreakEndSound()
            post(title: NotificationCopy.breakTitles.randomElement() ?? "Break is over",
                 body: NotificationCopy.breakBodies.randomElement() ?? "Back to work.",
                 category: Category.breakEnded)
        }
    }

    func appBlocked(_ appName: String) {
        post(title: "\(appName) is on your blocking list",
             body: "Blocked apps are unavailable during a focus session.",
             category: Category.appBlocked)
    }

    private func post(title: String, body: String, category: String) {
        guard settings.allowDesktopNotifications, let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Tells the user notifications are switched off in System Settings.
    func showDisabledAlert() {
        let alert = NSAlert()
        alert.messageText = "Allow Notifications"
        alert.informativeText = "Notifications are disabled in System Settings. "
            + "Open System Settings to allow notifications and try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case "start":
                FocusTimer.shared.start()
            case "skip":
                FocusTimer.shared.skip()
            default:
                WindowCoordinator.shared.showMainWindow()
            }
            handler()
        }
    }
}
