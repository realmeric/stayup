import Foundation

/// One input, read on demand, with a way to say it changed.
///
/// `onChange` is what lets a source pull the engine forward rather than wait
/// for the next 20 s tick: heat and the cable both announce themselves.
protocol ThermalSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    func read() -> ThermalLevel
}

final class MachineThermalSource: ThermalSource {
    var onChange: (() -> Void)?
    private var observer: NSObjectProtocol?

    init(center: NotificationCenter = .default) {
        observer = center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
                                      object: nil,
                                      queue: .main) { [weak self] _ in
            Log.sources.debug("thermal state changed")
            self?.onChange?()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func read() -> ThermalLevel {
        FakeEnvironment.thermal ?? Thermal.read()
    }
}
