import AppKit

/// AppleScript bridge:
/// `tell application "Focus" to start` and friends.
@objc(StartScriptCommand)
final class StartScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.start()
        return FocusTimer.shared.phase.title
    }
}

@objc(StopScriptCommand)
final class StopScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.pause()
        return FocusTimer.shared.phase.title
    }
}

@objc(SkipScriptCommand)
final class SkipScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.skip()
        return FocusTimer.shared.phase.title
    }
}

@objc(PreviousScriptCommand)
final class PreviousScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.previous()
        return FocusTimer.shared.phase.title
    }
}

@objc(ResetScriptCommand)
final class ResetScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.restartCycle()
        return FocusTimer.shared.phase.title
    }
}

@objc(ShowScriptCommand)
final class ShowScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        WindowCoordinator.shared.showMainWindow()
        return FocusTimer.shared.phase.title
    }
}

@objc(HideScriptCommand)
final class HideScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        WindowCoordinator.shared.hideMainWindow()
        return FocusTimer.shared.phase.title
    }
}

@objc(GetCurrentPhaseScriptCommand)
final class GetCurrentPhaseScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.phase.rawValue
    }
}

@objc(GetRemainingTimeScriptCommand)
final class GetRemainingTimeScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        FocusTimer.shared.clock
    }
}

@objc(SetSessionTitleScriptCommand)
final class SetSessionTitleScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if let title = evaluatedArguments?["titleParameter"] as? String {
            FocusTimer.shared.setTitle(title)
        }
        return AppSettings.shared.sessionTitle
    }
}

@objc(GetSessionTitleScriptCommand)
final class GetSessionTitleScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AppSettings.shared.sessionTitle
    }
}

/// Keeps the command classes referenced so the linker preserves them —
/// Cocoa only looks them up by name from the .sdef.
enum ScriptCommandRegistry {
    static let classes: [AnyClass] = [
        StartScriptCommand.self, StopScriptCommand.self, SkipScriptCommand.self,
        PreviousScriptCommand.self, ResetScriptCommand.self, ShowScriptCommand.self,
        HideScriptCommand.self, GetCurrentPhaseScriptCommand.self,
        GetRemainingTimeScriptCommand.self, SetSessionTitleScriptCommand.self,
        GetSessionTitleScriptCommand.self,
    ]
}
