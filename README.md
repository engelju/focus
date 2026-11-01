# Focus

A Pomodoro timer that lives in the macOS menu bar, with no Dock icon. Native
SwiftUI/AppKit app, built with SwiftPM — no external dependencies.

```bash
make            # build, assemble the bundle, install to /Applications
make run        # same, then (re)launch
make stop       # quit a running instance
```

Every build replaces `/Applications/Focus.app`, so the app can be launched
straight from Spotlight.

## Features

**Timer**
- Phases `focus → shortBreak → … → longBreak`, default 25 / 5 / 30 minutes,
  long break after 4 sessions (all configurable)
- Remaining time is computed from a wall-clock end date, so it stays correct
  across display sleep
- Start / Stop / Skip / Previous / Reset / Restart Cycle
- Auto-start for sessions and breaks
- **Commitment mode**: pause, skip and reset are locked while a focus session
  is running
- Session title ("What are you working on?"), optionally shown in the menu bar

**Menu bar**
- Three icon styles: `default` (pie chart), `circular` (ring), `progressBar` —
  drawn at runtime with CoreGraphics
- Template icon (adapts to light/dark), optionally tinted during breaks
- Left click opens/closes the window, right click opens the menu

**Windows**
- Resizable timer window (minimum 220 × 268) with progress ring, cycle dots and
  title field; the ring grows with the window
- Fullscreen break screen with a quote; ⎋, ⌘M or *Minimize* hide it while the
  break keeps running
- Settings, Statistics, "How It Works", Welcome, About

**Statistics**
- Sessions are logged as JSON to
  `~/Library/Application Support/Focus/sessions.json`
- Day/week/month/year, sessions or minutes view, Swift Charts bars
- Streak, per-session detail view including interruptions
- Export as `.csv` / `.txt`, reset statistics

**More**
- Notifications with Start/Skip actions and rotating messages
- Alarm sounds (system sounds) with volume, synthesized ticking (1 Hz)
- Global hotkeys via Carbon — **no** Accessibility permission needed;
  defaults: ⌃⌥F start/stop, ⌃⌥H window, ⌃⌥S skip, ⌃⌥R reset
- App blocker: apps on the list are hidden during a focus session
- Login item via `SMAppService`

## Remote control

URL scheme:

```bash
open -g "focus://start"          # also: stop, toggle, skip, reset, restart
open -g "focus://show"           # also: hide, statistics, settings
open -g "focus://title?value=Write%20report"
```

AppleScript. On first use macOS asks once for Automation permission for the
calling program — until it is granted, the command hangs. The URL scheme above
needs no permission:

```bash
osascript -e 'tell application "Focus" to start'
osascript -e 'tell application "Focus" to getTime'
osascript -e 'tell application "Focus" to setTitle to "Write report"'
```

## Not included

Some features can't be built locally without a developer account,
entitlements or third-party services, so they are left out rather than faked:

| Feature | Reason |
|---|---|
| Website blocker | Controls browsers via Apple Events; needs Automation permission per browser |
| Calendar sync | EventKit needs a signed, entitled bundle |
| iCloud timer sync | A CloudKit container requires an Apple Developer team |
| Widget & App Intents | Separate extension targets, only possible with an Xcode project |

## Layout

```
Sources/Focus/
  main.swift              AppDelegate, main menu, URL scheme
  ScriptCommands.swift    AppleScript commands
  Snapshot.swift          FOCUS_SNAPSHOT=<dir> renders views offscreen as PNG
  Model/                  Phase, Session, SessionStore, AppSettings
  Services/               FocusTimer, Sound, Notifications, HotKeys, AppBlocker
  UI/                     Windows, menu bar, ring, settings, statistics
Bundle/                   Info.plist, Focus.sdef, generated AppIcon.icns
Scripts/build-app.sh      builds Focus.app, ad-hoc signs it, moves it to /Applications
Scripts/make-icon.swift   renders the app icon
```

Settings are stored in `UserDefaults` under `local.focus.Focus`
(`flow.durationInMinutes`, `enableCommitmentMode`, `menuBarIconStyle`, …);
inspect them with `defaults read local.focus.Focus`.

## License

[MIT](LICENSE)
