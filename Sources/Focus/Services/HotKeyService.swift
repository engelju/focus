import AppKit
import Carbon.HIToolbox

/// A recorded key combination.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    /// `NSEvent.ModifierFlags` raw value.
    var modifiers: UInt

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var displayString: String {
        var out = ""
        if flags.contains(.control) { out += "⌃" }
        if flags.contains(.option) { out += "⌥" }
        if flags.contains(.shift) { out += "⇧" }
        if flags.contains(.command) { out += "⌘" }
        out += KeyCombo.name(for: keyCode)
        return out
    }

    static func name(for keyCode: UInt32) -> String {
        if let name = keyNames[Int(keyCode)] { return name }
        return "Key \(keyCode)"
    }

    private static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_Period: ".", kVK_ANSI_Comma: ",",
        kVK_ANSI_Slash: "/", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]", kVK_ANSI_Backslash: "\\",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// System-wide hotkeys, registered through Carbon so no accessibility
/// permission is required.
final class HotKeyService {
    static let shared = HotKeyService()

    enum Action: String, CaseIterable, Identifiable {
        case toggleTimer, toggleWindow, skip, reset

        var id: String { rawValue }

        var title: String {
            switch self {
            case .toggleTimer: return "Start or stop timer"
            case .toggleWindow: return "Show or hide window"
            case .skip: return "Skip session or break"
            case .reset: return "Reset current session"
            }
        }

        var defaultCombo: KeyCombo {
            let mods = NSEvent.ModifierFlags([.control, .option]).rawValue
            switch self {
            case .toggleTimer: return KeyCombo(keyCode: UInt32(kVK_ANSI_F), modifiers: mods)
            case .toggleWindow: return KeyCombo(keyCode: UInt32(kVK_ANSI_H), modifiers: mods)
            case .skip: return KeyCombo(keyCode: UInt32(kVK_ANSI_S), modifiers: mods)
            case .reset: return KeyCombo(keyCode: UInt32(kVK_ANSI_R), modifiers: mods)
            }
        }

        var defaultsKey: String { "KeyboardShortcuts_\(rawValue)" }
    }

    private var refs: [Action: EventHotKeyRef] = [:]
    private var ids: [UInt32: Action] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "enableGlobalHotkeys") }
        set {
            UserDefaults.standard.set(newValue, forKey: "enableGlobalHotkeys")
            newValue ? registerAll() : unregisterAll()
        }
    }

    private init() {
        UserDefaults.standard.register(defaults: ["enableGlobalHotkeys": true])
    }

    // MARK: - Stored combos

    func combo(for action: Action) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: action.defaultsKey) else {
            return action.defaultCombo
        }
        if data.isEmpty { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    func setCombo(_ combo: KeyCombo?, for action: Action) {
        if let combo, let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: action.defaultsKey)
        } else {
            UserDefaults.standard.set(Data(), forKey: action.defaultsKey)
        }
        registerAll()
    }

    // MARK: - Registration

    func registerAll() {
        unregisterAll()
        guard enabled else { return }
        installHandler()
        for action in Action.allCases {
            guard let combo = combo(for: action) else { continue }
            register(combo, for: action)
        }
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        ids.removeAll()
    }

    private func register(_ combo: KeyCombo, for action: Action) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x464F_4353), id: id) // 'FOCS'
        let status = RegisterEventHotKey(combo.keyCode,
                                        carbonModifiers(combo.flags),
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &ref)
        if status == noErr, let ref {
            refs[action] = ref
            ids[id] = action
        } else {
            NSLog("Focus: could not register hotkey for \(action.rawValue) (status \(status))")
        }
    }

    private func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { HotKeyService.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func fire(_ id: UInt32) {
        guard let action = ids[id] else { return }
        switch action {
        case .toggleTimer: FocusTimer.shared.toggle()
        case .toggleWindow: WindowCoordinator.shared.toggleMainWindow()
        case .skip: FocusTimer.shared.skip()
        case .reset: FocusTimer.shared.reset()
        }
    }
}
