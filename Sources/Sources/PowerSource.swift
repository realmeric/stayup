import Foundation

protocol PowerSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    func read() -> PowerReading
}

/// Polled on the tick rather than watched.
///
/// `IOPSNotificationCreateRunLoopSource` exists and would be exact, at the
/// cost of a C callback and an `Unmanaged` context pointer. The battery moves
/// by a percent every few minutes and the guard's thresholds are five points
/// apart, so twenty seconds of lag costs nothing that a callback would buy
/// back. `onChange` is here because the protocol has it; nothing calls it.
final class MachinePowerSource: PowerSource {
    var onChange: (() -> Void)?

    func read() -> PowerReading {
        FakeEnvironment.power ?? Power.read()
    }
}
