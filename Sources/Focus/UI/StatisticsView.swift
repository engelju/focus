import Charts
import SwiftUI

private struct Bucket: Identifiable {
    var id: String { label }
    var label: String
    var sessions: Int
    var minutes: Double
}

struct StatisticsView: View {
    @State private var store = SessionStore.shared
    @State private var settings = AppSettings.shared
    @State private var period: StatisticsPeriod = .week
    @State private var selected: Session?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    chart
                    sessionList
                }
                .padding(18)
            }
        }
        .frame(minWidth: 720, minHeight: 540)
        .sheet(item: $selected) { session in
            SessionDetailView(session: session) { selected = nil }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { Text($0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .labelsHidden()

            Picker("", selection: $settings.selectedStatisticsUnit) {
                ForEach(StatisticsUnit.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            .labelsHidden()

            Spacer()

            Toggle("Incomplete", isOn: $settings.showIncompleteSessions)
                .toggleStyle(.checkbox)
                .help("Include sessions that were stopped early")

            Menu {
                Button("Export as .csv…") { export(csv: true) }
                Button("Export as .txt…") { export(csv: false) }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .fixedSize()

            Button("Reset Statistics", role: .destructive) { confirmReset() }
        }
        .padding(12)
    }

    // MARK: - Summary

    private var focusSessions: [Session] {
        store.focusSessions(in: period, includeIncomplete: settings.showIncompleteSessions)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(title: "Sessions",
                     value: "\(focusSessions.count)",
                     caption: period.title,
                     tint: .focusAccent)
            StatTile(title: "Focused",
                     value: formatMinutes(focusSessions.reduce(0) { $0 + $1.activeSeconds }),
                     caption: period.title,
                     tint: .focusAccent)
            StatTile(title: "Breaks",
                     value: "\(store.sessions(in: period, includeIncomplete: settings.showIncompleteSessions).filter { $0.phase.isBreak }.count)",
                     caption: period.title,
                     tint: .breakAccent)
            StatTile(title: "Streak",
                     value: "\(store.streakDays)",
                     caption: store.streakDays == 1 ? "day" : "days",
                     tint: .breakAccent)
        }
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return String(format: "%dh %02dm", minutes / 60, minutes % 60)
        }
        return "\(minutes)m"
    }

    // MARK: - Chart

    private var buckets: [Bucket] {
        let sessions = focusSessions
        return period.buckets().map { bucket in
            let inBucket = sessions.filter { $0.startedAt >= bucket.start && $0.startedAt < bucket.end }
            return Bucket(label: bucket.label,
                          sessions: inBucket.count,
                          minutes: Double(inBucket.reduce(0) { $0 + $1.activeSeconds }) / 60)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.selectedStatisticsUnit == .count ? "Sessions" : "Minutes")
                .font(.headline)
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.label),
                    y: .value(settings.selectedStatisticsUnit.title,
                              settings.selectedStatisticsUnit == .count ? Double(bucket.sessions) : bucket.minutes)
                )
                .foregroundStyle(Color.focusAccent.gradient)
                .cornerRadius(3)
            }
            .chartXScale(domain: buckets.map(\.label))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: period == .month ? 8 : 12)) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Statistics chart")
        }
    }

    // MARK: - Session list

    private var listedSessions: [Session] {
        store.sessions.filter { settings.showIncompleteSessions || $0.completed }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Sessions")
                .font(.headline)
            if listedSessions.isEmpty {
                VStack(spacing: 6) {
                    Text("No Sessions Found").font(.headline)
                    Text("Complete your first focus session to see a detailed overview.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(listedSessions.prefix(200)) { session in
                        SessionRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture { selected = session }
                            .contextMenu {
                                Button("Delete", role: .destructive) { store.delete(session) }
                            }
                        Divider()
                    }
                }
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Actions

    private func export(csv: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = csv ? "focus-sessions.csv" : "focus-sessions.txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = csv ? store.csv() : store.plainText()
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to reset your statistics?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.deleteAll()
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: String
    var caption: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SessionRow: View {
    var session: Session

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session.phase.symbol)
                .font(.system(size: 11))
                .foregroundStyle(session.phase.tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.phase == .focus ? session.title : session.phase.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(Self.formatter.string(from: session.startedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !session.interruptions.isEmpty {
                Label("\(session.interruptions.count)", systemImage: "pause.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text("\(session.activeSeconds / 60) min")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Image(systemName: session.completed ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 11))
                .foregroundStyle(session.completed ? session.phase.tint : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct SessionDetailView: View {
    var session: Session
    var dismiss: () -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(.headline)
                .padding(.bottom, 10)
            Form {
                LabeledContent("Type", value: session.phase.title)
                LabeledContent("Title", value: session.title)
                LabeledContent("Started", value: Self.formatter.string(from: session.startedAt))
                LabeledContent("Stopped", value: session.finishedAt.map { Self.formatter.string(from: $0) } ?? "—")
                LabeledContent("Completed", value: session.completed ? "Yes" : "No")
                LabeledContent("Duration", value: formatClock(session.activeSeconds))
                LabeledContent("With Interruptions", value: formatClock(session.elapsedWithInterruptions))
                LabeledContent("Interruptions", value: "\(session.interruptions.count)")
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 10)
        }
        .padding(18)
        .frame(width: 380)
    }
}
