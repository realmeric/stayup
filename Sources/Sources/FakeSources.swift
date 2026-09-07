import Foundation

/// The environment hooks, so the guards can be exercised on a Mac that will
/// not get hot and a lid that is in the other room.
///
///     STAYUP_FAKE_THERMAL=nominal|fair|serious|critical
///     STAYUP_FAKE_POWER=ac|battery:<percent>
///     STAYUP_FAKE_LID=open|closed
///     STAYUP_FAKE_AGENT=busy|idle
///
/// Read on every tick rather than at launch, so a value can be changed by
/// relaunching, which is all the manual pass needs. In the app target on
/// purpose: `make run` is where these are used.
enum FakeEnvironment {
    static var thermal: ThermalLevel? {
        switch value("STAYUP_FAKE_THERMAL") {
        case "nominal": return .nominal
        case "fair": return .fair
        case "serious": return .serious
        case "critical": return .critical
        default: return nil
        }
    }

    static var power: PowerReading? {
        guard let text = value("STAYUP_FAKE_POWER") else { return nil }
        if text == "ac" { return PowerReading(onAC: true, percent: 100) }
        guard text.hasPrefix("battery:"), let percent = Int(text.dropFirst("battery:".count)) else {
            return nil
        }
        return PowerReading(onAC: false, percent: percent)
    }

    static var lidClosed: Bool? {
        switch value("STAYUP_FAKE_LID") {
        case "closed": return true
        case "open": return false
        default: return nil
        }
    }

    /// `busy` is a write this instant, `idle` is no write at all. Anything
    /// else leaves the real directories to answer.
    static func agentWrite(now: Date) -> Date?? {
        switch value("STAYUP_FAKE_AGENT") {
        case "busy": return .some(now)
        case "idle": return .some(nil)
        default: return nil
        }
    }

    private static func value(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]?.lowercased()
    }
}

// MARK: - What the tests hold

final class FakeThermalSource: ThermalSource {
    var onChange: (() -> Void)?
    var level: ThermalLevel = .nominal
    func read() -> ThermalLevel { level }
}

final class FakePowerSource: PowerSource {
    var onChange: (() -> Void)?
    var reading = PowerReading(onAC: true, percent: 100)
    func read() -> PowerReading { reading }
}

final class FakeLidSource: LidSource {
    var onChange: (() -> Void)?
    var closed = false
    func read() -> Bool { closed }
}

final class FakeAgentSource: AgentSource {
    var onChange: (() -> Void)?
    var lastWrite: Date?
    func read() -> Date? { lastWrite }
}

final class RecordingNotifier: Notifying {
    private(set) var notices: [Notice] = []
    func deliver(_ notice: Notice) { notices.append(notice) }
}
