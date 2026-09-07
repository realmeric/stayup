import AppKit
import SwiftUI

/// The one engine and the one settings window, reachable from the delegate,
/// the status item and the menu.
@MainActor
enum Live {
    static let engine = Engine()
    static let settingsWindow = SettingsWindow { room in
        AnyView(SettingsView(room: room).environmentObject(Live.engine))
    }
}

/// An AppKit entry point rather than a SwiftUI `App`.
///
/// There is no scene to declare. The interface is a status item and a window
/// opened on demand, and a SwiftUI `App` with only a `Settings` scene does not
/// build that scene at all (`docs/notes.md`, "The menu bar item"). SwiftUI is
/// still what draws the settings; it is hosted rather than staged.
@main
enum Main {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
