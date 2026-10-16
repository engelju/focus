import AppKit

/// The status item: a progress glyph plus the remaining time, and a menu
/// with the same commands as the window.
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let settings = AppSettings.shared
    private let timer = FocusTimer.shared

    private override init() { super.init() }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(buttonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        statusItem = item
        refresh()
    }

    // MARK: - Click handling

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu()
        } else {
            WindowCoordinator.shared.toggleMainWindow()
        }
    }

    private func showMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let toggleTitle = timer.isRunning ? "Stop" : (timer.remainingSeconds < timer.plannedSeconds ? "Resume" : "Start")
        menu.addItem(header("\(timer.phase.title) — \(timer.clock)   \(timer.cyclePosition)"))
        menu.addItem(.separator())
        menu.addItem(action(toggleTitle, #selector(toggleTimer), enabled: !timer.isLocked))
        menu.addItem(action("Skip", #selector(skip), enabled: !timer.isLocked))
        menu.addItem(action("Reset", #selector(reset), enabled: !timer.isLocked))
        menu.addItem(action("Restart Cycle", #selector(restartCycle), enabled: !timer.isLocked))
        menu.addItem(.separator())
        menu.addItem(action(WindowCoordinator.shared.isMainWindowVisible ? "Hide Window" : "Show Window",
                            #selector(toggleWindow)))
        menu.addItem(action("Statistics…", #selector(showStatistics)))
        menu.addItem(action("Settings…", #selector(showSettings)))
        menu.addItem(action("How It Works…", #selector(showHowItWorks)))
        menu.addItem(.separator())
        menu.addItem(action("About Focus", #selector(showAbout)))
        menu.addItem(action("Quit Focus", #selector(quit)))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        return item
    }

    @objc private func toggleTimer() { timer.toggle() }
    @objc private func skip() { timer.skip() }
    @objc private func reset() { timer.reset() }
    @objc private func restartCycle() { timer.restartCycle() }
    @objc private func toggleWindow() { WindowCoordinator.shared.toggleMainWindow() }
    @objc private func showStatistics() { WindowCoordinator.shared.showStatistics() }
    @objc private func showSettings() { WindowCoordinator.shared.showSettings() }
    @objc private func showHowItWorks() { WindowCoordinator.shared.showHowItWorks() }
    @objc private func showAbout() { WindowCoordinator.shared.showAbout() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Rendering

    func refresh() {
        guard let button = statusItem?.button else { return }
        button.image = icon()
        button.attributedTitle = NSAttributedString(string: titleText(), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
        ])
        button.toolTip = "\(timer.phase.title) · \(timer.clock)"
    }

    private func titleText() -> String {
        var parts: [String] = []
        if settings.timeInMenuBarIcon { parts.append(timer.clock) }
        if settings.titleInMenuBarIcon, timer.phase == .focus { parts.append(settings.sessionTitle) }
        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: " · ")
    }

    private var useColor: Bool {
        settings.coloredIconDuringBreak && timer.phase.isBreak
    }

    private func icon() -> NSImage {
        let progress = timer.progress
        let paused = timer.state == .paused
        let color: NSColor = useColor ? .breakAccentNS : .labelColor

        let size: NSSize
        switch settings.menuBarIconStyle {
        case .progressBar: size = NSSize(width: 26, height: 16)
        case .default, .circular: size = NSSize(width: 16, height: 16)
        }

        let image = NSImage(size: size, flipped: false) { [settings] rect in
            color.withAlphaComponent(paused ? 0.45 : 1).setStroke()
            color.withAlphaComponent(paused ? 0.45 : 1).setFill()

            switch settings.menuBarIconStyle {
            case .default:
                Self.drawPie(in: rect, progress: progress, color: color, paused: paused)
            case .circular:
                Self.drawRing(in: rect, progress: progress, color: color, paused: paused)
            case .progressBar:
                Self.drawBar(in: rect, progress: progress, color: color, paused: paused)
            }
            return true
        }
        image.isTemplate = !useColor
        return image
    }

    private static func drawPie(in rect: NSRect, progress: Double, color: NSColor, paused: Bool) {
        let inset: CGFloat = 1.5
        let circle = rect.insetBy(dx: inset, dy: inset)
        let outline = NSBezierPath(ovalIn: circle)
        outline.lineWidth = 1.4
        color.withAlphaComponent(paused ? 0.35 : 0.85).setStroke()
        outline.stroke()

        guard progress > 0.001 else { return }
        let center = NSPoint(x: circle.midX, y: circle.midY)
        let radius = circle.width / 2 - 1.6
        let wedge = NSBezierPath()
        wedge.move(to: center)
        wedge.appendArc(withCenter: center,
                        radius: radius,
                        startAngle: 90,
                        endAngle: 90 - 360 * progress,
                        clockwise: true)
        wedge.close()
        color.withAlphaComponent(paused ? 0.4 : 1).setFill()
        wedge.fill()
    }

    private static func drawRing(in rect: NSRect, progress: Double, color: NSColor, paused: Bool) {
        let circle = rect.insetBy(dx: 2, dy: 2)
        let center = NSPoint(x: circle.midX, y: circle.midY)
        let radius = circle.width / 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = 2
        color.withAlphaComponent(0.25).setStroke()
        track.stroke()

        guard progress > 0.001 else { return }
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center,
                      radius: radius,
                      startAngle: 90,
                      endAngle: 90 - 360 * progress,
                      clockwise: true)
        arc.lineWidth = 2
        arc.lineCapStyle = .round
        color.withAlphaComponent(paused ? 0.45 : 1).setStroke()
        arc.stroke()
    }

    private static func drawBar(in rect: NSRect, progress: Double, color: NSColor, paused: Bool) {
        let bar = NSRect(x: rect.minX + 1, y: rect.midY - 3, width: rect.width - 2, height: 6)
        let track = NSBezierPath(roundedRect: bar, xRadius: 3, yRadius: 3)
        color.withAlphaComponent(0.22).setFill()
        track.fill()

        guard progress > 0.001 else { return }
        let filledWidth = max(2, (bar.width - 2) * progress)
        let filled = NSRect(x: bar.minX + 1, y: bar.minY + 1, width: filledWidth, height: bar.height - 2)
        let path = NSBezierPath(roundedRect: filled, xRadius: 2, yRadius: 2)
        color.withAlphaComponent(paused ? 0.45 : 1).setFill()
        path.fill()
    }
}
