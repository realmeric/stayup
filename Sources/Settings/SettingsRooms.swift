import Foundation

/// The rooms of the settings window.
///
/// Every choice the app has is reachable through one of these. That is the
/// point of them: a setting that exists but has no control is a setting only
/// its author knows about, and `SettingsRoomTests` fails until each one has a
/// room to live in.
enum SettingsRoom: String, CaseIterable, Identifiable {
    case general
    case sessions
    case agents
    case guards
    case appearance
    case helper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .sessions: return "Sessions"
        case .agents: return "Agents"
        case .guards: return "Guards"
        case .appearance: return "Appearance"
        case .helper: return "Helper"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .sessions: return "clock"
        case .agents: return "text.append"
        case .guards: return "shield"
        case .appearance: return "paintpalette"
        case .helper: return "key"
        }
    }
}
