import Foundation

protocol LidSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    func read() -> Bool
}

/// Read on the tick. There is no cheap notification for the clamshell, and
/// the only thing the answer decides is whether a release is followed by a
/// `sleepnow`, which is a question asked at the moment of the release.
final class MachineLidSource: LidSource {
    var onChange: (() -> Void)?

    func read() -> Bool {
        FakeEnvironment.lidClosed ?? Lid.isClosed()
    }
}
