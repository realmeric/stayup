import AppKit

/// Everything the app does at launch that is not a view.
///
/// The unit test bundle is hosted by the app, so `xcodebuild test` runs this
/// for real. Under XCTest it returns before touching anything, or every test
/// run would start ticking the engine and reaching for `sudo`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    /// Set once launch has actually happened, so a view can tell the
    /// difference between "not started" and "started under test".
    private(set) var launched = false

    static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isTesting else { return }
        // Belt and braces with LSUIElement: the plist keeps it off the Dock
        // before launch, this keeps it off after, and neither depends on the
        // other being right.
        NSApp.setActivationPolicy(.accessory)
        launched = true
        Log.app.info("launched \(AppInfo.version, privacy: .public)")
        // Once, now, so the icon is right before the first twenty seconds are
        // up rather than after them.
        Live.engine.startTicking()
        statusItem = StatusItemController(engine: Live.engine)
        HotkeyCenter.shared.action = {
            Log.menu.debug("shortcut fired")
            Live.engine.toggleQuickStart()
        }
        Live.engine.adoptHotkey()
        // After the first tick, so the helper status is known: starting into a
        // missing rule would only log a refusal.
        if Live.engine.settings.startOnLaunch {
            Live.engine.toggleQuickStart()
        }
    }

    /// Quit means off, whatever the mode and however the quit arrived. The
    /// menu's Quit has already done this by the time we get here; a quit from
    /// anywhere else has not.
    func applicationWillTerminate(_ notification: Notification) {
        guard launched else { return }
        Live.engine.stop(reason: .quit)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
