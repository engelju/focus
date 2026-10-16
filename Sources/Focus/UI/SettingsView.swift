import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            TimerSettings().tabItem { Label("Timer", systemImage: "timer") }
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "menubar.rectangle") }
            SoundSettings().tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            BlockerSettings().tabItem { Label("Blocker", systemImage: "hand.raised") }
            ShortcutSettings().tabItem { Label("Shortcuts", systemImage: "command") }
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 430)
    }
}

// MARK: - Timer

private struct TimerSettings: View {
    @State private var settings = AppSettings.shared
    private let timer = FocusTimer.shared

    var body: some View {
        Form {
            Section("Custom Durations") {
                minuteStepper("Focus", value: $settings.flowDuration, range: 1...180)
                minuteStepper("Short Break", value: $settings.shortBreakDuration, range: 1...60)
                minuteStepper("Long Break", value: $settings.longBreakDuration, range: 1...120)
                Stepper(value: $settings.cycleLength, in: 2...12) {
                    HStack {
                        Text("Long break after…")
                        Spacer()
                        Text("\(settings.cycleLength) sessions")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                HStack {
                    Spacer()
                    Button("Reset to 25 / 5 / 30") {
                        settings.resetDurations()
                        timer.durationsChanged()
                    }
                }
            }

            Section {
                Toggle("Start Focus Sessions Automatically", isOn: $settings.startFlowsAutomatically)
                Toggle("Start Breaks Automatically", isOn: $settings.startBreaksAutomatically)
                Toggle("Commitment Mode", isOn: $settings.enableCommitmentMode)
                Text("When enabled, you can't pause, skip or restart a running focus session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.flowDuration) { _, _ in timer.durationsChanged() }
        .onChange(of: settings.shortBreakDuration) { _, _ in timer.durationsChanged() }
        .onChange(of: settings.longBreakDuration) { _, _ in timer.durationsChanged() }
    }

    private func minuteStepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue) min")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Menu Bar") {
                Picker("Icon Style", selection: $settings.menuBarIconStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show remaining time", isOn: $settings.timeInMenuBarIcon)
                Toggle("Show session title in menu bar", isOn: $settings.titleInMenuBarIcon)
                Toggle("Show colored icon during break", isOn: $settings.coloredIconDuringBreak)
                Text("Focus is a menu bar app without a dock icon. If you can't see the timer, "
                     + "there are too many icons in your menu bar — rearrange them while holding ⌘.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Theme") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Break Screen") {
                Toggle("Fullscreen at start of break", isOn: $settings.maximizeAtBreak)
                Toggle("Show motivational quotes", isOn: $settings.showMotivationalQuotes)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.menuBarIconStyle) { _, _ in MenuBarController.shared.refresh() }
        .onChange(of: settings.timeInMenuBarIcon) { _, _ in MenuBarController.shared.refresh() }
        .onChange(of: settings.titleInMenuBarIcon) { _, _ in MenuBarController.shared.refresh() }
        .onChange(of: settings.coloredIconDuringBreak) { _, _ in MenuBarController.shared.refresh() }
    }
}

// MARK: - Sounds

private struct SoundSettings: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Alerts") {
                Picker("When a focus session ends", selection: $settings.flowEndSound) {
                    ForEach(AlertSounds.all, id: \.self) { Text($0).tag($0) }
                }
                Picker("When a break ends", selection: $settings.breakEndSound) {
                    ForEach(AlertSounds.all, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Notification Volume")
                    Slider(value: $settings.notificationVolume, in: 0...1)
                    Button("Test") { SoundService.shared.playFlowEndSound() }
                }
            }

            Section {
                Toggle("Enable Ticking Sound", isOn: $settings.enableTickingSound)
                Text("A soft tick once per second while a focus session runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Allow Desktop Notifications", isOn: $settings.allowDesktopNotifications)
                Button("Open Notification Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.flowEndSound) { _, new in SoundService.shared.play(named: new) }
        .onChange(of: settings.breakEndSound) { _, new in SoundService.shared.play(named: new) }
        .onChange(of: settings.notificationVolume) { _, _ in SoundService.shared.refreshTickingVolume() }
        .onChange(of: settings.enableTickingSound) { _, on in
            SoundService.shared.setTicking(on && FocusTimer.shared.isRunning && FocusTimer.shared.phase == .focus)
        }
    }
}

// MARK: - Blocker

private struct BlockerSettings: View {
    @State private var settings = AppSettings.shared
    @State private var selection: String?

    var body: some View {
        Form {
            Section("App Blocker") {
                Toggle("Block apps during focus sessions", isOn: $settings.enableAppBlocker)
                Text("Apps on the list are hidden while a focus session runs — not during a break "
                     + "or while the timer is paused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if settings.blockedAppPaths.isEmpty {
                    Text("No apps on the list yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    List(selection: $selection) {
                        ForEach(settings.blockedAppPaths, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(nsImage: AppBlocker.icon(for: path))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                Text(AppBlocker.displayName(for: path))
                                Spacer()
                            }
                            .tag(path)
                        }
                    }
                    .frame(height: 150)
                }
                HStack {
                    Button("Add…") { AppBlocker.shared.pickApps() }
                    Button("Remove") {
                        if let selection {
                            settings.blockedAppPaths.removeAll { $0 == selection }
                            self.selection = nil
                        }
                    }
                    .disabled(selection == nil)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutSettings: View {
    @State private var globalEnabled = HotKeyService.shared.enabled

    var body: some View {
        Form {
            Section("Global Shortcuts") {
                Toggle("Enable Global Hotkeys", isOn: $globalEnabled)
                Text("Global shortcuts work regardless of which app is in focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(HotKeyService.Action.allCases) { action in
                    ShortcutRecorder(action: action)
                        .disabled(!globalEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: globalEnabled) { _, on in HotKeyService.shared.enabled = on }
    }
}

/// Records a key combination for one action.
private struct ShortcutRecorder: View {
    let action: HotKeyService.Action

    @State private var combo: KeyCombo?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(action.title)
            Spacer()
            Button(label) { recording ? stop() : start() }
                .frame(minWidth: 90)
            Button {
                HotKeyService.shared.setCombo(nil, for: action)
                combo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(combo == nil ? 0 : 1)
            .help("Clear shortcut")
        }
        .onAppear { combo = HotKeyService.shared.combo(for: action) }
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return "Type shortcut…" }
        return combo?.displayString ?? "Record"
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 { // Escape cancels
                stop()
                return nil
            }
            guard !flags.intersection([.command, .option, .control, .shift]).isEmpty else {
                NSSound.beep()
                return nil
            }
            let new = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: flags.rawValue)
            HotKeyService.shared.setCombo(new, for: action)
            combo = new
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Launch") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Toggle("Show Window at Launch", isOn: $settings.showWindowAtLaunch)
                Toggle("Start Timer at Launch", isOn: $settings.startTimerAtLaunch)
                Toggle("Reset Cycle at Launch", isOn: $settings.resetCycleAtLaunch)
            }

            Section("Window") {
                Toggle("Hide Window When Timer Starts", isOn: $settings.hideWindowOnTimerStart)
                Toggle("Keep Window on Top", isOn: $settings.keepWindowOnTop)
            }

            Section("Data") {
                HStack {
                    Text("Session log")
                    Spacer()
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([SessionStore.shared.storageURL])
                    }
                }
                HStack {
                    Text("Statistics")
                    Spacer()
                    Button("Open…") { WindowCoordinator.shared.showStatistics() }
                }
            }

            Section {
                HStack {
                    Button("How It Works…") { WindowCoordinator.shared.showHowItWorks() }
                    Spacer()
                    Button("About Focus") { WindowCoordinator.shared.showAbout() }
                }
            }
        }
        .formStyle(.grouped)
    }
}
