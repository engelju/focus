import SwiftUI

/// The three kinds of segment a cycle is made of.
enum Phase: String, Codable, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var shortTitle: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak, .longBreak: return "Break"
        }
    }

    var isBreak: Bool { self != .focus }

    var symbol: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "figure.walk"
        }
    }

    var tint: Color {
        switch self {
        case .focus: return .focusAccent
        case .shortBreak, .longBreak: return .breakAccent
        }
    }
}

/// Lifecycle of the timer.
enum RunState: String, Codable {
    case pending
    case running
    case paused
    case completed
}

extension Color {
    /// Warm amber used while focusing.
    static let focusAccent = Color(red: 0.95, green: 0.40, blue: 0.22)
    /// Calm teal used during breaks.
    static let breakAccent = Color(red: 0.18, green: 0.72, blue: 0.63)
}

extension NSColor {
    static let focusAccentNS = NSColor(red: 0.95, green: 0.40, blue: 0.22, alpha: 1)
    static let breakAccentNS = NSColor(red: 0.18, green: 0.72, blue: 0.63, alpha: 1)
}

func formatClock(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%02d:%02d", m, sec)
}
