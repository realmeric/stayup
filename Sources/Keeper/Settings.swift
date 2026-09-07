import Foundation

/// Every number the app has an opinion about, with the opinion beside it.
///
/// A new field here needs a control in `SettingsView` and a line in
/// `SettingsRoomTests`, which walks these out of the type and fails until
/// somebody says where the control went.
struct Settings: Codable, Equatable {
    /// What the menu offers, in seconds: 30 m, 1 h, 2 h, 5 h, 8 h.
    var durations: [TimeInterval] = [1800, 3600, 7200, 18000, 28800]
    /// How long Indefinite lasts before it stops itself. 0 means never, which
    /// is the setting this whole app exists because of.
    var indefiniteCap: TimeInterval = 86400
    var thermalPauseLevel: ThermalLevel = .critical
    /// How long the heat has to stay down before a thermal pause lifts.
    var thermalCalm: TimeInterval = 120
    var batteryFloor: Int = 15
    var batteryResume: Int = 20
    var onlyWhileCharging: Bool = false
    /// How long a transcript can go unwritten before the agents count as done.
    /// Three minutes, not seconds: a long tool call is silence, not idleness.
    var idleTimeout: TimeInterval = 180
    /// How long Follow waits before it starts believing the silence, so the
    /// session can be started before the agent.
    var followGrace: TimeInterval = 300
    var followCap: TimeInterval = 28800
    var watchedDirectories: [String] = ["~/.claude/projects", "~/.codex/sessions"]
    var notifications: Bool = true
    var warnBeforeEnd: TimeInterval = 300

    static let defaults = Settings()
}
