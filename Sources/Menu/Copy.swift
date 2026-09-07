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

    // MARK: - The settings window

    static let roomSessions = "Sessions"
    static let roomAgents = "Agents"
    static let roomGuards = "Guards"
    static let roomHelper = "Helper"

    static let indefiniteCap = "Stop indefinite sessions after"
    static let warnBeforeEnd = "Warn before the end"
    static let notifications = "Notifications"
    static let durations = "Durations in the menu"
    static let addDuration = "Add a duration"
    static let remove = "Remove"

    static let idleTimeout = "Call the agents idle after"
    static let followGrace = "Wait this long before believing it"
    static let followCap = "Stop following after"
    static let watchedDirectories = "Transcripts to watch"
    static let addDirectory = "Add a directory"

    static let heat = "Heat"
    static let battery = "Battery"
    static let thermalPauseLevel = "Pause at"
    static let levelCritical = "Critical"
    static let levelSerious = "Serious"
    static let thermalCalm = "Resume after this much calm"
    static let batteryFloor = "Pause below"
    static let batteryResume = "Resume at"

    static let helperRule = "Sudoers rule"
    static let helperGuard = "Guard agent"
    static let installed = "Installed"
    static let notInstalled = "Not installed"
    static let installHelper = "Install…"
    static let removeHelper = "Remove…"
    static let helperExplanation = """
        StayUp asks for your password once, to allow itself two commands \
        without one: raising and lowering the sleep flag. Removing it takes \
        away the rule, the guard that clears a forgotten flag every minute, \
        and the reset that clears one at boot.
        """

    /// 0 hours is not "0 h"; it is the setting this app exists because of.
    static func cap(_ seconds: TimeInterval) -> String {
        seconds == 0 ? "no cap" : duration(seconds)
    }
}
