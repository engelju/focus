import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let timer = FocusTimer.shared
    private var previousState: RunState = .pending

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ScriptCommandRegistry.classes

        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = settings.appearance.nsAppearance

        buildMainMenu()
        MenuBarController.shared.install()
        NotificationService.shared.bootstrap()
        HotKeyService.shared.registerAll()

        timer.onTick = { [weak self] in
            MenuBarController.shared.refresh()
            self?.handleStateChange()
        }
        timer.onPhaseCompleted = { finished, next in
            NotificationService.shared.phaseCompleted(finished, next: next)
            if next.isBreak {
                WindowCoordinator.shared.showBreakWindow()
            } else {
                WindowCoordinator.shared.hideBreakWindow()
            }
        }

        if settings.showWelcomeWindow {
            WindowCoordinator.shared.showWelcomeIfNeeded()
        } else if settings.showWindowAtLaunch {
            WindowCoordinator.shared.showMainWindow()
        }

        if settings.startTimerAtLaunch {
            timer.start()
        }
        MenuBarController.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SoundService.shared.setTicking(false)
        HotKeyService.shared.unregisterAll()
    }

    /// Hides the window when the timer starts, if the setting is on.
    private func handleStateChange() {
        let state = timer.state
        defer { previousState = state }
        guard state != previousState else { return }
        if state == .running, settings.hideWindowOnTimerStart, !timer.phase.isBreak {
            WindowCoordinator.shared.hideMainWindow()
        }
    }

    // MARK: - URL scheme (focus://start, focus://skip, …)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let command = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
            switch command {
            case "start": timer.start()
            case "stop", "pause": timer.pause()
            case "toggle": timer.toggle()
            case "skip": timer.skip()
            case "reset": timer.reset()
            case "restart", "restartcycle": timer.restartCycle()
            case "show": WindowCoordinator.shared.showMainWindow()
            case "hide": WindowCoordinator.shared.hideMainWindow()
            case "statistics": WindowCoordinator.shared.showStatistics()
            case "settings": WindowCoordinator.shared.showSettings()
            case "title":
                if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "value" })?.value {
                    timer.setTitle(value)
                }
            default: break
            }
        }
    }

    // MARK: - Menus

    @objc private func showSettings() { WindowCoordinator.shared.showSettings() }
    @objc private func showStatistics() { WindowCoordinator.shared.showStatistics() }
    @objc private func showAbout() { WindowCoordinator.shared.showAbout() }
    @objc private func showHowItWorks() { WindowCoordinator.shared.showHowItWorks() }
    @objc private func toggleTimer() { timer.toggle() }
    @objc private func skipSession() { timer.skip() }
    @objc private func resetSession() { timer.reset() }
    @objc private func restartCycle() { timer.restartCycle() }
    @objc private func showWindow() { WindowCoordinator.shared.showMainWindow() }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Focus", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Statistics…", action: #selector(showStatistics), keyEquivalent: "l")
        appMenu.addItem(withTitle: "How It Works…", action: #selector(showHowItWorks), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Focus", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Focus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in appMenu.items where item.action == #selector(showAbout)
            || item.action == #selector(showSettings)
            || item.action == #selector(showStatistics)
            || item.action == #selector(showHowItWorks) {
            item.target = self
        }
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // Timer menu
        let timerItem = NSMenuItem()
        let timerMenu = NSMenu(title: "Timer")
        let entries: [(String, Selector, String)] = [
            ("Start / Stop", #selector(toggleTimer), " "),
            ("Skip", #selector(skipSession), "k"),
            ("Reset", #selector(resetSession), "r"),
            ("Restart Cycle", #selector(restartCycle), "R"),
        ]
        for (title, selector, key) in entries {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            timerMenu.addItem(item)
        }
        timerItem.submenu = timerMenu
        mainMenu.addItem(timerItem)

        // Edit menu — needed for copy/paste in the session title field.
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        // Window menu
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let show = NSMenuItem(title: "Focus Timer", action: #selector(showWindow), keyEquivalent: "0")
        show.target = self
        windowMenu.addItem(show)
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

let app = NSApplication.shared
if MainActor.assumeIsolated({ Snapshot.runIfRequested() }) { exit(0) }
let delegate = AppDelegate()
app.delegate = delegate
app.run()
