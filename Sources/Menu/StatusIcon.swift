import Foundation

/// The icon, as a function of the status and nothing else.
///
/// The label of a `MenuBarExtra` is re-evaluated when the status it reads
/// changes, so there is nothing to keep in sync: name the symbol for the
/// state and the menu bar follows.
enum StatusIcon {
    static func name(for status: Status) -> String {
        // Nothing else is true while the rule is missing: the app cannot
        // raise the flag, so whatever else the status says is a plan rather
        // than a state.
        if status.helper == .missing { return "exclamationmark.triangle" }
        switch status.paused {
        case .thermal: return "thermometer.high"
        case .battery: return "battery.25percent"
        case .charging: return "bolt.slash"
        case nil: break
        }
        return status.raised ? "sun.max.fill" : "moon.zzz"
    }
}
