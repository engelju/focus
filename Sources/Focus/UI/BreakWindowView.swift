import SwiftUI

/// Fullscreen break screen, shown when "Fullscreen at start of break" is on.
struct BreakWindowView: View {
    @State private var timer = FocusTimer.shared
    @State private var settings = AppSettings.shared
    @State private var quote = Quotes.random()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.breakAccent.opacity(0.22), Color.breakAccent.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Label(timer.phase.title, systemImage: timer.phase.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.breakAccent)

                ZStack {
                    RingView(progress: timer.progress, tint: .breakAccent, lineWidth: 14,
                             paused: timer.state == .paused)
                    Text(timer.clock)
                        .font(.system(size: 76, weight: .light, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 260, height: 260)

                if settings.showMotivationalQuotes {
                    VStack(spacing: 6) {
                        Text("“\(quote.text)”")
                            .font(.system(size: 16, design: .serif))
                            .italic()
                            .multilineTextAlignment(.center)
                        Text("— \(quote.author)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 460)
                }

                HStack(spacing: 14) {
                    Button(timer.isRunning ? "Pause" : "Start Break") { timer.toggle() }
                        .controlSize(.large)
                    Button("Skip Break") {
                        timer.skip()
                        WindowCoordinator.shared.hideBreakWindow()
                    }
                    .controlSize(.large)
                }

                Text("Press ⎋ to close this screen")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(40)
        }
        .onAppear { quote = Quotes.random() }
        .onChange(of: timer.phase) { _, phase in
            if phase == .focus { WindowCoordinator.shared.hideBreakWindow() }
        }
    }
}
