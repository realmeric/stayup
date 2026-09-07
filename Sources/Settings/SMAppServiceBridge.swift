import Foundation
import ServiceManagement

/// Launch at login, in one place.
///
/// The menu and the settings window both offer it, and both have to read back
/// the real status rather than what was asked for: registering can fail, and a
/// switch that lies about it is worse than one that snaps back.
enum SMAppServiceBridge {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ wanted: Bool) {
        do {
            if wanted {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.menu.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
