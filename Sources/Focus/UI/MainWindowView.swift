import SwiftUI

/// The timer window: 220 × 268 at minimum, the ring grows when it is resized.
struct MainWindowView: View {
    static let minSize = CGSize(width: 220, height: 268)
    /// Size the window opens at the first time.
    static let defaultSize = CGSize(width: 380, height: 268)
    /// Ring diameter at the minimum window size.
    private static let baseRing: CGFloat = 128

    @State private var timer = FocusTimer.shared
    @State private var settings = AppSettings.shared
    @State private var titleDraft: String = AppSettings.shared.sessionTitle
    @FocusState private var titleFocused: Bool

    private var tint: Color { timer.phase.tint }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                Spacer(minLength: 6)
                ring(diameter: ringDiameter(for: proxy.size))
                Spacer(minLength: 6)
                titleField
                Spacer(minLength: 10)
                controls
            }
            .padding(16)
        }
        .frame(minWidth: Self.minSize.width, maxWidth: .infinity,
               minHeight: Self.minSize.height, maxHeight: .infinity)
        .background(.background)
        .onChange(of: settings.sessionTitle) { _, new in
            if !titleFocused { titleDraft = new }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: timer.phase.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(timer.phase.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            if timer.state == .paused {
                Text("· Paused")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(timer.cyclePosition)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            MainMenuButton()
        }
        .foregroundStyle(tint)
    }

    // MARK: - Ring

    /// Extra height goes to the ring; it is capped by the window width.
    private func ringDiameter(for size: CGSize) -> CGFloat {
        let byHeight = Self.baseRing + size.height - Self.minSize.height
        let byWidth = size.width - 32
        return max(Self.baseRing, min(byHeight, byWidth))
    }

    private func ring(diameter: CGFloat) -> some View {
        let scale = diameter / Self.baseRing
        return ZStack {
            // The stroke grows slower than the ring so a big ring doesn't look heavy.
            RingView(progress: timer.progress, tint: tint, lineWidth: 9 * scale.squareRoot(),
                     paused: timer.state == .paused)
            VStack(spacing: 6 * scale) {
                Text(timer.clock)
                    .font(.system(size: 36 * scale, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                CycleDots(completed: timer.completedFlowsInCycle,
                          total: settings.cycleLength,
                          tint: tint)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    // MARK: - Session title

    @ViewBuilder
    private var titleField: some View {
        if timer.phase == .focus {
            TextField("What are you working on?", text: $titleDraft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .focused($titleFocused)
                .onSubmit { commitTitle() }
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitTitle() }
                }
                .frame(height: 18)
        } else {
            Text(breakHint)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 18)
        }
    }

    private var breakHint: String {
        timer.phase == .longBreak
            ? "Step away for a while — you earned it."
            : "Stand up, stretch, drink water."
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        timer.setTitle(trimmed)
        titleDraft = settings.sessionTitle
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "arrow.counterclockwise", help: "Reset session") {
                timer.reset()
            }
            .disabled(timer.isLocked)

            Button(action: { timer.toggle() }) {
                Text(timer.isRunning ? "Stop" : (timer.remainingSeconds < timer.plannedSeconds ? "Resume" : "Start"))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 96, maxWidth: 128, minHeight: 30, maxHeight: 30)
                    .background(tint.opacity(timer.isLocked && timer.isRunning ? 0.45 : 1), in: Capsule())
                    // A plain button only hit-tests what it draws; make the whole capsule clickable.
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(timer.isLocked)
            .help(timer.isLocked ? "Commitment mode is on — stay with it." : "Start or stop the timer")

            CircleButton(symbol: "forward.end.fill", help: "Skip to the next session") {
                timer.skip()
            }
            .disabled(timer.isLocked)
        }
    }
}

/// Small round icon button used either side of the primary action.
struct CircleButton: View {
    var symbol: String
    var help: String
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(hovering ? 0.12 : 0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// The “⋯” menu in the window header.
struct MainMenuButton: View {
    @State private var settings = AppSettings.shared
    @State private var timer = FocusTimer.shared

    var body: some View {
        Menu {
            Button("Restart Cycle") { timer.restartCycle() }
                .disabled(timer.isLocked)
            Divider()
            Menu("Focus Duration") {
                ForEach([15, 20, 25, 30, 45, 50, 60], id: \.self) { minutes in
                    Button(durationLabel(minutes, selected: settings.flowDuration)) {
                        settings.flowDuration = minutes
                        timer.durationsChanged()
                    }
                }
            }
            Menu("Break Durations") {
                Section("Short Break") {
                    ForEach([3, 5, 10, 15], id: \.self) { minutes in
                        Button(durationLabel(minutes, selected: settings.shortBreakDuration)) {
                            settings.shortBreakDuration = minutes
                            timer.durationsChanged()
                        }
                    }
                }
                Section("Long Break") {
                    ForEach([15, 20, 30, 45], id: \.self) { minutes in
                        Button(durationLabel(minutes, selected: settings.longBreakDuration)) {
                            settings.longBreakDuration = minutes
                            timer.durationsChanged()
                        }
                    }
                }
            }
            Divider()
            Button("Statistics…") { WindowCoordinator.shared.showStatistics() }
            Button("Settings…") { WindowCoordinator.shared.showSettings() }
            Button("How It Works…") { WindowCoordinator.shared.showHowItWorks() }
            Divider()
            Button("About Focus") { WindowCoordinator.shared.showAbout() }
            Button("Quit Focus") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 18)
        .help("More")
    }

    private func durationLabel(_ minutes: Int, selected: Int) -> String {
        (minutes == selected ? "✓  " : "     ") + "\(minutes) min"
    }
}
