import Foundation
import UserNotifications

/// The banners.
///
/// Permission is asked for the first time a session starts rather than at
/// launch: an app that asks before it has done anything is asking you to
/// agree to a thing you have not seen yet.
final class UserNotifier: Notifying {
    private let center: UNUserNotificationCenter
    private let settings: () -> Settings
    private var asked = false

    init(center: UNUserNotificationCenter = .current(),
         settings: @escaping () -> Settings) {
        self.center = center
        self.settings = settings
    }

    func prepare() {
        guard !asked else { return }
        asked = true
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.app.error("notifications: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.app.info("notifications \(granted ? "allowed" : "refused", privacy: .public)")
            }
        }
    }

    func deliver(_ notice: Notice) {
        let settings = settings()
        let (title, body) = Copy.notice(notice, settings: settings)
        guard !title.isEmpty else { return }
        Log.app.info("notice: \(title, privacy: .public)")
        guard settings.notifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        content.sound = .default
        // The two that mean the Mac is about to sleep on you, and the one that
        // means it already stopped, get through a Focus. The rest do not.
        content.interruptionLevel = Self.isUrgent(notice) ? .timeSensitive : .active

        center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                         content: content,
                                         trigger: nil)) { error in
            if let error {
                Log.app.error("notification not delivered: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func isUrgent(_ notice: Notice) -> Bool {
        switch notice {
        case .paused(.thermal), .paused(.battery):
            return true
        case .ended(.cap):
            return true
        default:
            return false
        }
    }
}
