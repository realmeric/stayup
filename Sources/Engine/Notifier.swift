import Foundation

protocol Notifying {
    func deliver(_ notice: Notice)
    /// Called when a session starts, so permission can be asked for at the
    /// moment it is about to be used rather than at launch.
    func prepare()
}

extension Notifying {
    func prepare() {}
}

/// The default until S-09, and the fallback whenever notifications are off.
/// Nothing the app has to say is important enough to be lost, so it is said
/// here as well either way.
struct LoggingNotifier: Notifying {
    func deliver(_ notice: Notice) {
        Log.app.info("notice: \(String(describing: notice), privacy: .public)")
    }
}
