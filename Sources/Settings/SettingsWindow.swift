import AppKit
import SwiftUI

/// Hosts the settings in a window of its own.
///
/// A window built here rather than a SwiftUI `Settings` scene. Measured on
/// 2026-09-07: with `Settings` as the app's only scene, `showSettingsWindow:`
/// answers `true` and no window is ever made - not immediately, not two
/// seconds later, and not with the activation policy raised to `.regular`
/// first. An `NSWindow` around an `NSHostingView` has none of that between it
/// and the screen.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    private let content: (SettingsRoom) -> AnyView

    init(content: @escaping (SettingsRoom) -> AnyView) {
        self.content = content
    }

    func show(room: SettingsRoom = .general) {
        if let window {
            // Already open: bring it forward rather than rebuild it, which
            // would throw away where it was put and which room was being read.
            surface(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: SettingsView.width, height: SettingsView.height),
            // Resizable, because the rooms are not all the same height and the
            // longest of them should not be the size every other one is stuck
            // at.
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppInfo.name) Settings"
        window.contentView = NSHostingView(rootView: content(room))
        window.contentMinSize = NSSize(width: SettingsView.width, height: SettingsView.height)
        window.isReleasedWhenClosed = false
        // Remembered by AppKit, which also puts it back on a screen that still
        // exists - which hand-rolled position storage famously does not.
        window.setFrameAutosaveName("settings")
        if window.frame.origin == .zero { window.center() }
        self.window = window
        surface(window)
    }

    /// Bring the window to the front from an app that has no Dock tile.
    ///
    /// `makeKeyAndOrderFront` plus `activate` is not enough on its own: an
    /// accessory app is not always allowed to pull itself in front of whatever
    /// you are working in, and the window then opens silently behind
    /// everything. `orderFrontRegardless` is the part that does not ask.
    private func surface(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
