import AppKit

/// Hides apps from the blocklist while a focus session is running.
///
/// Blocking websites would mean rewriting browser tabs through AppleScript,
/// which needs Apple Events permission for every browser, so this sticks to
/// app blocking and leaves website blocking to the browser.
final class AppBlocker {
    static let shared = AppBlocker()

    private let settings = AppSettings.shared
    private var observer: NSObjectProtocol?
    private var lastNotified: [String: Date] = [:]
    private var active = false

    private init() {}

    func setActive(_ shouldBeActive: Bool) {
        let wanted = shouldBeActive && settings.enableAppBlocker && !settings.blockedAppPaths.isEmpty
        guard wanted != active else { return }
        active = wanted
        wanted ? startObserving() : stopObserving()
        if wanted { hideBlockedApps() }
    }

    private func startObserving() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handle(app)
        }
    }

    private func stopObserving() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func isBlocked(_ app: NSRunningApplication) -> Bool {
        guard let path = app.bundleURL?.path else { return false }
        return settings.blockedAppPaths.contains(path)
    }

    private func handle(_ app: NSRunningApplication) {
        guard active, isBlocked(app) else { return }
        app.hide()
        let name = app.localizedName ?? "This app"
        let now = Date()
        if let last = lastNotified[name], now.timeIntervalSince(last) < 20 { return }
        lastNotified[name] = now
        NotificationService.shared.appBlocked(name)
    }

    private func hideBlockedApps() {
        for app in NSWorkspace.shared.runningApplications where isBlocked(app) {
            app.hide()
        }
    }

    /// Opens an app picker and adds the chosen apps to the blocklist.
    func pickApps() {
        let panel = NSOpenPanel()
        panel.title = "Add apps to the blocklist"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        var paths = settings.blockedAppPaths
        for url in panel.urls where !paths.contains(url.path) {
            paths.append(url.path)
        }
        settings.blockedAppPaths = paths.sorted {
            ($0 as NSString).lastPathComponent.localizedCaseInsensitiveCompare(($1 as NSString).lastPathComponent) == .orderedAscending
        }
    }

    static func displayName(for path: String) -> String {
        (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
