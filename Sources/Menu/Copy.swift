import Foundation

/// Every string a person reads.
///
/// In one file because the menu is the whole interface: a string literal in a
/// view is a sentence nobody proof-read and nobody can test.
enum Copy {
    // MARK: - The status line

    static let off = "Off"
    static let setUpNeeded = "Set up needed"

    static func statusLine(_ status: Status, now: Date) -> String {
        if status.helper == .missing { return setUpNeeded }
        switch status.paused {
        case .thermal: return "Paused · too hot"
        case .battery: return "Paused · battery \(status.power.percent)%"
        case .charging: return "Paused · not charging"
        case nil: break
        }
        switch status.mode {
        case .off:
            return off
        case .timed(let until):
            return "Awake · \(duration(until.timeIntervalSince(now))) left"
        case .follow:
            return "Awake · until the agents finish · \(lastWrite(status.lastAgentWrite, now: now))"
        case .indefinite(let started):
            return "Awake · \(duration(now.timeIntervalSince(started)))"
        }
    }

    static func lastWrite(_ written: Date?, now: Date) -> String {
        guard let written else { return "never" }
        return "last write \(ago(now.timeIntervalSince(written)))"
    }

    /// Seconds while there are only seconds, then minutes, then hours. A
    /// number that changes every tick is a number nobody reads.
    static func ago(_ seconds: TimeInterval) -> String {
        let seconds = max(0, Int(seconds.rounded()))
        if seconds < 60 { return "\(seconds) s ago" }
        if seconds < 3600 { return "\(seconds / 60) m ago" }
        return "\(duration(TimeInterval(seconds))) ago"
    }

    /// `30 m`, `1 h`, `1 h 23 m`. Rounded down, because "1 h left" arriving
    /// four seconds early would be a lie in the wrong direction.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 { return "\(minutes) m" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) m"
    }

    // MARK: - The menu

    static func awakeFor(_ seconds: TimeInterval) -> String {
        "Awake for \(spelled(seconds))"
    }

    /// Words rather than the compact form, because this is an instruction and
    /// the status line is a reading.
    static func spelled(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 minutes" : parts.joined(separator: " ")
    }

    static let awakeUntilAgentsFinish = "Awake until the agents finish"
    static let awakeIndefinitely = "Awake indefinitely"
    static let stop = "Stop"
    static let pauseWhenHot = "Pause when hot"
    static let pauseOnLowBattery = "Pause on low battery"
    static let onlyWhileCharging = "Only while charging"
    static let settings = "Settings…"
    static let setUp = "Set up StayUp…"
    static let launchAtLogin = "Launch at login"
    static let quit = "Quit"
}
