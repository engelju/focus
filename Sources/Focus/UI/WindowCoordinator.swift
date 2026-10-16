import AppKit
import SwiftUI

/// Window that closes on ⎋ — used for the fullscreen break screen.
final class EscapableWindow: NSWindow {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Owns every window. The app is an accessory (no dock icon), so windows are
/// created lazily and the app is activated explicitly when one is shown.
final class WindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = WindowCoordinator()

    private var main: NSWindow?
    private var settingsWindow: NSWindow?
    private var statisticsWindow: NSWindow?
    private var howItWorksWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var breakWindow: EscapableWindow?

    private let settings = AppSettings.shared

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: .focusWindowLevelChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyWindowLevel()
        }
    }

    // MARK: - Main window

    func showMainWindow() {
        let window = mainWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hideMainWindow() {
        main?.orderOut(nil)
    }

    func toggleMainWindow() {
        if let main, main.isVisible {
            main.orderOut(nil)
        } else {
            showMainWindow()
        }
    }

    var isMainWindowVisible: Bool { main?.isVisible ?? false }

    private func mainWindow() -> NSWindow {
        if let main { return main }
        let controller = NSHostingController(rootView: MainWindowView())
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.title = "Focus"
        window.setContentSize(NSSize(width: 380, height: 268))
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        let hadSavedFrame = WindowCoordinator.hasSavedFrame(named: "FocusMainWindow")
        window.setFrameAutosaveName("FocusMainWindow")
        if !hadSavedFrame { window.center() }
        window.delegate = self
        main = window
        applyWindowLevel()
        return window
    }

    private func applyWindowLevel() {
        main?.level = settings.keepWindowOnTop ? .floating : .normal
    }

    // MARK: - Auxiliary windows

    func showSettings() {
        settingsWindow = present(settingsWindow, view: SettingsView(), title: "Settings",
                                 autosave: "FocusSettingsWindow", resizable: false)
    }

    func showStatistics() {
        statisticsWindow = present(statisticsWindow, view: StatisticsView(), title: "Statistics",
                                   autosave: "FocusStatisticsWindow", resizable: true)
    }

    func showHowItWorks() {
        howItWorksWindow = present(howItWorksWindow, view: HowItWorksView(), title: "How It Works",
                                   autosave: "FocusHowItWorksWindow", resizable: false)
    }

    func showAbout() {
        aboutWindow = present(aboutWindow, view: AboutView(), title: "About Focus",
                              autosave: nil, resizable: false)
    }

    func showWelcomeIfNeeded() {
        guard settings.showWelcomeWindow else { return }
        welcomeWindow = present(welcomeWindow,
                                view: WelcomeView { [weak self] in
                                    self?.welcomeWindow?.close()
                                    self?.welcomeWindow = nil
                                    self?.showMainWindow()
                                },
                                title: "Welcome",
                                autosave: nil,
                                resizable: false)
    }

    private func present<V: View>(_ existing: NSWindow?, view: V, title: String,
                                  autosave: String?, resizable: Bool) -> NSWindow {
        if let existing {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return existing
        }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = resizable ? [.titled, .closable, .resizable] : [.titled, .closable]
        window.title = title
        window.isReleasedWhenClosed = false
        // Give SwiftUI a chance to settle on its size before positioning,
        // otherwise every window ends up at the same cascade origin.
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(controller.view.fittingSize)
        let hadSavedFrame = autosave.map { WindowCoordinator.hasSavedFrame(named: $0) } ?? false
        if let autosave { window.setFrameAutosaveName(autosave) }
        if !hadSavedFrame { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    // MARK: - Break window

    func showBreakWindow() {
        guard settings.maximizeAtBreak else { return }
        if breakWindow == nil {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let window = EscapableWindow(contentRect: screen.frame,
                                         styleMask: [.borderless],
                                         backing: .buffered,
                                         defer: false)
            window.contentViewController = NSHostingController(rootView: BreakWindowView())
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .windowBackgroundColor
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.onCancel = { [weak self] in self?.hideBreakWindow() }
            breakWindow = window
        }
        if let screen = NSScreen.main {
            breakWindow?.setFrame(screen.frame, display: true)
        }
        NSApp.activate(ignoringOtherApps: true)
        breakWindow?.makeKeyAndOrderFront(nil)
    }

    func hideBreakWindow() {
        breakWindow?.orderOut(nil)
    }

    /// `setFrameAutosaveName` succeeds even when nothing was stored, so check
    /// the defaults key AppKit writes to decide whether to centre a window.
    private static func hasSavedFrame(named name: String) -> Bool {
        UserDefaults.standard.string(forKey: "NSWindow Frame \(name)") != nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // The app keeps running without windows; nothing to do.
    }
}
