import SwiftUI

/// The five-step explanation of the technique.
struct HowItWorksView: View {
    private struct Step: Identifiable {
        let id = UUID()
        let index: Int
        let title: String
        let detail: String
        let symbol: String
    }

    @State private var settings = AppSettings.shared

    private var steps: [Step] {
        [
            Step(index: 1, title: "Pick a task",
                 detail: "Choose one thing you want to work on from your to-do list.",
                 symbol: "checklist"),
            Step(index: 2, title: "Set the timer",
                 detail: "A short timespan of \(settings.flowDuration) minutes is ideal to stay focused.",
                 symbol: "timer"),
            Step(index: 3, title: "Focus on the task",
                 detail: "Once started, commit to it. This helps battle distractions.",
                 symbol: "brain.head.profile"),
            Step(index: 4, title: "Take a short break",
                 detail: "Enjoy a short \(settings.shortBreakDuration)-minute break. Stand up, stretch your legs, drink water.",
                 symbol: "cup.and.saucer"),
            Step(index: 5, title: "Take a long break",
                 detail: "Every \(settings.cycleLength)th break is a long, more restorative \(settings.longBreakDuration)-minute break.",
                 symbol: "figure.walk"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How it works")
                        .font(.title2.weight(.semibold))
                    Text("Focus is based on a popular focus timer method — the Pomodoro Technique. "
                         + "By default it consists of four simple steps.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.focusAccent.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: step.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.focusAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Step \(step.index) · \(step.title)")
                                .font(.system(size: 13, weight: .semibold))
                            Text(step.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    if step.index == 4 {
                        Text("Repeat \(settings.cycleLength) times, then…")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.focusAccent)
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 440, height: 520)
    }
}

/// The welcome screen on first launch.
struct WelcomeView: View {
    @State private var settings = AppSettings.shared
    var done: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "timer")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(Color.focusAccent)
            Text("Welcome to Focus")
                .font(.title2.weight(.semibold))
            Text("Focus divides your work into sessions with defined breaks to help you stay "
                 + "focused and productive. It lives in your menu bar — there is no dock icon.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                bullet("timer", "\(settings.flowDuration) min focus, \(settings.shortBreakDuration) min break, "
                       + "\(settings.longBreakDuration) min after \(settings.cycleLength) sessions")
                bullet("command", "Global hotkeys for start, skip, reset and window")
                bullet("chart.bar", "Statistics with CSV export")
                bullet("hand.raised", "Optional app blocker during focus")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("Show this window at launch", isOn: $settings.showWelcomeWindow)
                .font(.caption)

            Button("Get Started") { done() }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 16)
                .foregroundStyle(Color.focusAccent)
            Text(text).font(.system(size: 12))
            Spacer()
        }
    }
}

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(Color.focusAccent)
            Text("Focus").font(.title2.weight(.semibold))
            Text(version).font(.caption).foregroundStyle(.secondary)
            Text("A dependency-free menu bar focus timer, written in SwiftUI.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 320)
    }
}
