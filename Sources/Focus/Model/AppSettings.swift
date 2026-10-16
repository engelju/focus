import AppKit
import Observation
import ServiceManagement

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case `default`, circular, progressBar

    var id: String { rawValue }
    var title: String {
        switch self {
        case .default: return "Default"
        case .circular: return "Circular"
        case .progressBar: return "Progress Bar"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Every user preference, persisted in `UserDefaults`.
/// Inspect them with `defaults read local.focus.Focus`.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let d = UserDefaults.standard

    // Durations & cycle
    var flowDuration: Int { didSet { d.set(flowDuration, forKey: "flow.durationInMinutes") } }
    var shortBreakDuration: Int { didSet { d.set(shortBreakDuration, forKey: "shortBreak.durationInMinutes") } }
    var longBreakDuration: Int { didSet { d.set(longBreakDuration, forKey: "longBreak.durationInMinutes") } }
    var cycleLength: Int { didSet { d.set(cycleLength, forKey: "cycleLength") } }

    // Behaviour
    var startFlowsAutomatically: Bool { didSet { d.set(startFlowsAutomatically, forKey: "startFlowsAutomatically") } }
    var startBreaksAutomatically: Bool { didSet { d.set(startBreaksAutomatically, forKey: "startBreaksAutomatically") } }
    var enableCommitmentMode: Bool { didSet { d.set(enableCommitmentMode, forKey: "enableCommitmentMode") } }
    var sessionTitle: String { didSet { d.set(sessionTitle, forKey: "lastTitle") } }

    // Sound
    var enableTickingSound: Bool { didSet { d.set(enableTickingSound, forKey: "enableTickingSound") } }
    var flowEndSound: String { didSet { d.set(flowEndSound, forKey: "flowEndSound") } }
    var breakEndSound: String { didSet { d.set(breakEndSound, forKey: "breakEndSound") } }
    var notificationVolume: Double { didSet { d.set(notificationVolume, forKey: "notificationVolume") } }

    // Notifications
    var allowDesktopNotifications: Bool { didSet { d.set(allowDesktopNotifications, forKey: "allowDesktopNotifications") } }
    var showMotivationalQuotes: Bool { didSet { d.set(showMotivationalQuotes, forKey: "showMotivationalQuotes") } }

    // Menu bar / appearance
    var menuBarIconStyle: MenuBarStyle { didSet { d.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") } }
    var titleInMenuBarIcon: Bool { didSet { d.set(titleInMenuBarIcon, forKey: "titleInMenuBarIcon") } }
    var timeInMenuBarIcon: Bool { didSet { d.set(timeInMenuBarIcon, forKey: "timeInMenuBarIcon") } }
    var coloredIconDuringBreak: Bool { didSet { d.set(coloredIconDuringBreak, forKey: "coloredIconDuringBreak") } }
    var appearance: AppearanceMode {
        didSet {
            d.set(appearance.rawValue, forKey: "appearance")
            NSApp.appearance = appearance.nsAppearance
        }
    }

    // Windows & launch
    var launchAtLogin: Bool {
        didSet {
            d.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }
    var resetCycleAtLaunch: Bool { didSet { d.set(resetCycleAtLaunch, forKey: "resetCycleAtLaunch") } }
    var startTimerAtLaunch: Bool { didSet { d.set(startTimerAtLaunch, forKey: "startTimerAtLaunch") } }
    var showWindowAtLaunch: Bool { didSet { d.set(showWindowAtLaunch, forKey: "showWindowAtLaunch") } }
    var hideWindowOnTimerStart: Bool { didSet { d.set(hideWindowOnTimerStart, forKey: "hideWindowOnTimerStart") } }
    var maximizeAtBreak: Bool { didSet { d.set(maximizeAtBreak, forKey: "maximizeAtBreak") } }
    var keepWindowOnTop: Bool {
        didSet {
            d.set(keepWindowOnTop, forKey: "keepWindowOnTop")
            NotificationCenter.default.post(name: .focusWindowLevelChanged, object: nil)
        }
    }

    // Blocker
    var blockedAppPaths: [String] { didSet { d.set(blockedAppPaths, forKey: "blockedAppPaths") } }
    var enableAppBlocker: Bool { didSet { d.set(enableAppBlocker, forKey: "enableAppBlocker") } }

    // Statistics
    var selectedStatisticsUnit: StatisticsUnit { didSet { d.set(selectedStatisticsUnit.rawValue, forKey: "selectedStatisticsUnit") } }
    var showIncompleteSessions: Bool { didSet { d.set(showIncompleteSessions, forKey: "showIncompleteSessions") } }

    // Onboarding
    var showWelcomeWindow: Bool { didSet { d.set(showWelcomeWindow, forKey: "showWelcomeWindow") } }

    private init() {
        d.register(defaults: [
            "flow.durationInMinutes": 25,
            "shortBreak.durationInMinutes": 5,
            "longBreak.durationInMinutes": 30,
            "cycleLength": 4,
            "startFlowsAutomatically": false,
            "startBreaksAutomatically": false,
            "enableCommitmentMode": false,
            "lastTitle": "Focus",
            "enableTickingSound": false,
            "flowEndSound": "Glass",
            "breakEndSound": "Ping",
            "notificationVolume": 0.7,
            "allowDesktopNotifications": true,
            "showMotivationalQuotes": true,
            "menuBarIconStyle": MenuBarStyle.default.rawValue,
            "titleInMenuBarIcon": false,
            "timeInMenuBarIcon": true,
            "coloredIconDuringBreak": true,
            "appearance": AppearanceMode.system.rawValue,
            "launchAtLogin": false,
            "resetCycleAtLaunch": true,
            "startTimerAtLaunch": false,
            "showWindowAtLaunch": true,
            "hideWindowOnTimerStart": true,
            "maximizeAtBreak": true,
            "keepWindowOnTop": false,
            "enableAppBlocker": false,
            "selectedStatisticsUnit": StatisticsUnit.count.rawValue,
            "showIncompleteSessions": false,
            "showWelcomeWindow": true,
        ])

        flowDuration = d.integer(forKey: "flow.durationInMinutes")
        shortBreakDuration = d.integer(forKey: "shortBreak.durationInMinutes")
        longBreakDuration = d.integer(forKey: "longBreak.durationInMinutes")
        cycleLength = d.integer(forKey: "cycleLength")
        startFlowsAutomatically = d.bool(forKey: "startFlowsAutomatically")
        startBreaksAutomatically = d.bool(forKey: "startBreaksAutomatically")
        enableCommitmentMode = d.bool(forKey: "enableCommitmentMode")
        sessionTitle = d.string(forKey: "lastTitle") ?? "Focus"
        enableTickingSound = d.bool(forKey: "enableTickingSound")
        flowEndSound = d.string(forKey: "flowEndSound") ?? "Glass"
        breakEndSound = d.string(forKey: "breakEndSound") ?? "Ping"
        notificationVolume = d.double(forKey: "notificationVolume")
        allowDesktopNotifications = d.bool(forKey: "allowDesktopNotifications")
        showMotivationalQuotes = d.bool(forKey: "showMotivationalQuotes")
        menuBarIconStyle = MenuBarStyle(rawValue: d.string(forKey: "menuBarIconStyle") ?? "") ?? .default
        titleInMenuBarIcon = d.bool(forKey: "titleInMenuBarIcon")
        timeInMenuBarIcon = d.bool(forKey: "timeInMenuBarIcon")
        coloredIconDuringBreak = d.bool(forKey: "coloredIconDuringBreak")
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        launchAtLogin = d.bool(forKey: "launchAtLogin")
        resetCycleAtLaunch = d.bool(forKey: "resetCycleAtLaunch")
        startTimerAtLaunch = d.bool(forKey: "startTimerAtLaunch")
        showWindowAtLaunch = d.bool(forKey: "showWindowAtLaunch")
        hideWindowOnTimerStart = d.bool(forKey: "hideWindowOnTimerStart")
        maximizeAtBreak = d.bool(forKey: "maximizeAtBreak")
        keepWindowOnTop = d.bool(forKey: "keepWindowOnTop")
        blockedAppPaths = d.stringArray(forKey: "blockedAppPaths") ?? []
        enableAppBlocker = d.bool(forKey: "enableAppBlocker")
        selectedStatisticsUnit = StatisticsUnit(rawValue: d.string(forKey: "selectedStatisticsUnit") ?? "") ?? .count
        showIncompleteSessions = d.bool(forKey: "showIncompleteSessions")
        showWelcomeWindow = d.bool(forKey: "showWelcomeWindow")
    }

    func duration(for phase: Phase) -> Int {
        switch phase {
        case .focus: return flowDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    /// Back to the 25/5/30 defaults.
    func resetDurations() {
        flowDuration = 25
        shortBreakDuration = 5
        longBreakDuration = 30
        cycleLength = 4
    }

    private func applyLaunchAtLogin() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Focus: could not change login item: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let focusWindowLevelChanged = Notification.Name("focusWindowLevelChanged")
}

/// The system alert sounds the app offers.
enum AlertSounds {
    static let all: [String] = {
        let names = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
                     "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
        return ["None"] + names.filter { NSSound(named: $0) != nil }
    }()
}
