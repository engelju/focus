import Foundation
import Observation

/// Persists finished sessions as a single JSON file in Application Support.
/// A flat file keeps the app dependency-free while still supporting
/// queries, export and reset.
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [Session] = []

    private let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Focus", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.url = base.appendingPathComponent("sessions.json")
        }
        load()
    }

    var storageURL: URL { url }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        sessions = (try? decoder.decode([Session].self, from: data)) ?? []
        sessions.sort { $0.startedAt > $1.startedAt }
    }

    private func persist() {
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func save(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        sessions.sort { $0.startedAt > $1.startedAt }
        persist()
    }

    func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    func deleteAll() {
        sessions.removeAll()
        persist()
    }

    // MARK: - Queries

    func sessions(in period: StatisticsPeriod, includeIncomplete: Bool) -> [Session] {
        let start = period.start()
        return sessions.filter {
            $0.startedAt >= start && (includeIncomplete || $0.completed)
        }
    }

    func focusSessions(in period: StatisticsPeriod, includeIncomplete: Bool) -> [Session] {
        sessions(in: period, includeIncomplete: includeIncomplete).filter { $0.phase == .focus }
    }

    /// Consecutive days (ending today or yesterday) with at least one completed focus session.
    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(sessions.filter { $0.phase == .focus && $0.completed }
            .map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Export

    func csv() -> String {
        var lines = ["Type,Title,Started,Finished,Minutes,Completed,Interruptions"]
        let fmt = ISO8601DateFormatter()
        for s in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let title = s.title.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append([
                s.phase.title,
                "\"\(title)\"",
                fmt.string(from: s.startedAt),
                s.finishedAt.map { fmt.string(from: $0) } ?? "",
                String(format: "%.1f", Double(s.activeSeconds) / 60),
                s.completed ? "yes" : "no",
                String(s.interruptions.count),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    func plainText() -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        var out = ["Focus — session log", ""]
        for s in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let minutes = Double(s.activeSeconds) / 60
            out.append("\(fmt.string(from: s.startedAt))  \(s.phase.title.padding(toLength: 12, withPad: " ", startingAt: 0))"
                + String(format: "%6.1f min", minutes)
                + (s.completed ? "  ✓" : "  ·")
                + (s.phase == .focus && !s.title.isEmpty ? "  \(s.title)" : ""))
        }
        return out.joined(separator: "\n")
    }
}
