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
    /// The menu's `Pause when hot`. The level below says how hot; this says
    /// whether to look at all, because a switch you can find in one click is
    /// worth more at two in the morning than a picker in a window.
    var pauseWhenHot: Bool = true
    var thermalPauseLevel: ThermalLevel = .critical
    /// How long the heat has to stay down before a thermal pause lifts.
    var thermalCalm: TimeInterval = 120
    var pauseOnLowBattery: Bool = true
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

    // MARK: What one click does

    /// What a left click on the icon, and the hotkey, start.
    ///
    /// Indefinite by default, because a click on a coffee cup means "keep it
    /// awake until I say otherwise" and the cap is what keeps that honest.
    var quickStart: QuickStart = .indefinite
    /// Start a session the moment StayUp launches, without being asked.
    ///
    /// Off by default. The whole reason this app exists is a flag nobody
    /// turned off, and a Mac that starts holding it at login is one step from
    /// that; but a login item that does nothing until you click it is not much
    /// of a login item either, so the choice is yours and the cap still holds.
    var startOnLaunch: Bool = false
    var hotkeyEnabled: Bool = true
    /// Control-Option-Command-B. Registered through Carbon, which needs no
    /// Accessibility permission; a global `NSEvent` monitor would.
    var hotkey: Hotkey = .default

    // MARK: How it looks

    var iconStyle: IconStyle = .coffee
    var awakeColor: String = Palette.defaultAwake
    var idleColor: String = Palette.defaultIdle

    static let defaults = Settings()
}

/// What one click starts. The duration is carried even when the choice is not
/// timed, so switching to Timed and back does not forget the number.
enum QuickStart: Codable, Equatable, Hashable {
    case timed(TimeInterval)
    case follow
    case indefinite
}
