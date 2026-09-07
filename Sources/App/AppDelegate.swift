import AppKit

/// Everything the app does at launch that is not a view.
///
/// The unit test bundle is hosted by the app, so `xcodebuild test` runs this
/// for real. Under XCTest it returns before touching anything, or every test
/// run would start ticking the engine and reaching for `sudo`.
final class AppDelegate: NSObject, NSApplicationDelegate {
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
