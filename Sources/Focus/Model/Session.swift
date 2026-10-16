import Foundation

/// One recorded segment: type, title, started, completed, duration,
/// interruptions.
struct Session: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var phase: Phase
    var title: String
    var startedAt: Date
    var finishedAt: Date?
    /// Seconds actually spent in the segment, interruptions excluded.
    var activeSeconds: Int
    /// Planned length of the segment in seconds.
    var plannedSeconds: Int
    var completed: Bool
    var interruptions: [Interruption]

    var elapsedWithInterruptions: Int {
        guard let finishedAt else { return activeSeconds }
        return Int(finishedAt.timeIntervalSince(startedAt).rounded())
    }

    var interruptionSeconds: Int {
        max(0, elapsedWithInterruptions - activeSeconds)
    }
}

/// A pause inside a session.
struct Interruption: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var startedAt: Date
    var finishedAt: Date?

    var seconds: Int {
        guard let finishedAt else { return 0 }
        return Int(finishedAt.timeIntervalSince(startedAt).rounded())
    }
}

enum StatisticsUnit: String, CaseIterable, Identifiable {
    case count
    case time

    var id: String { rawValue }
    var title: String { self == .count ? "Sessions" : "Minutes" }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        case .year: return "Y"
        }
    }

    var title: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    /// Start of the current period.
    func start(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .day: return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    /// The buckets the chart is drawn from, oldest first.
    func buckets(calendar: Calendar = .current, now: Date = Date()) -> [(label: String, start: Date, end: Date)] {
        var result: [(String, Date, Date)] = []
        let fmt = DateFormatter()
        switch self {
        case .day:
            let dayStart = calendar.startOfDay(for: now)
            for hour in stride(from: 0, to: 24, by: 2) {
                guard let s = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let e = calendar.date(byAdding: .hour, value: 2, to: s) else { continue }
                result.append((String(format: "%02d", hour), s, e))
            }
        case .week:
            let s0 = start(from: now, calendar: calendar)
            fmt.locale = .current
            fmt.setLocalizedDateFormatFromTemplate("EEE")
            for day in 0..<7 {
                guard let s = calendar.date(byAdding: .day, value: day, to: s0),
                      let e = calendar.date(byAdding: .day, value: 1, to: s) else { continue }
                result.append((fmt.string(from: s), s, e))
            }
        case .month:
            let s0 = start(from: now, calendar: calendar)
            let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            for day in 0..<days {
                guard let s = calendar.date(byAdding: .day, value: day, to: s0),
                      let e = calendar.date(byAdding: .day, value: 1, to: s) else { continue }
                result.append((String(day + 1), s, e))
            }
        case .year:
            let s0 = start(from: now, calendar: calendar)
            fmt.locale = .current
            fmt.setLocalizedDateFormatFromTemplate("MMM")
            for month in 0..<12 {
                guard let s = calendar.date(byAdding: .month, value: month, to: s0),
                      let e = calendar.date(byAdding: .month, value: 1, to: s) else { continue }
                result.append((fmt.string(from: s), s, e))
            }
        }
        return result.map { (label: $0.0, start: $0.1, end: $0.2) }
    }
}
