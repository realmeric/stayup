import AppKit
import ServiceManagement

/// The menu, built in AppKit.
///
/// A real `NSMenu` rather than SwiftUI's `MenuBarExtra`, because the icon has
/// to tell a left click from a right one: `MenuBarExtra` swallows both and
/// opens the menu either way, and a left click here means "keep the Mac
/// awake", not "show me a list".
///
/// Rebuilt from the status every time it opens. A menu bar menu is on screen
/// for two seconds at a time, so there is nothing to keep in sync and no state
/// to go stale.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let engine: Engine
    let menu = NSMenu()

    init(engine: Engine) {
        self.engine = engine
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = engine.status
        let settings = engine.settings

        // What is happening, in one line, always first.
        let heading = NSMenuItem(title: Copy.statusLine(status, now: Date()),
                                 action: nil, keyEquivalent: "")
        heading.isEnabled = false
        heading.attributedTitle = NSAttributedString(
            string: heading.title,
            attributes: [.font: NSFont.menuBarFont(ofSize: 0),
                         .foregroundColor: NSColor.labelColor])
        menu.addItem(heading)

        if let error = status.error {
            let line = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
        }

        menu.addItem(.separator())

        if status.helper == .missing {
            add(Copy.setUp, #selector(setUp))
            menu.addItem(.separator())
        }

        if status.mode.isActive {
            add(Copy.stop, #selector(stop))
        } else {
            for seconds in settings.durations {
                let item = add(Copy.awakeFor(seconds), #selector(startTimed(_:)))
                item.representedObject = seconds
                item.isEnabled = status.helper == .installed
            }
            add(Copy.awakeUntilAgentsFinish, #selector(startFollow))
                .isEnabled = status.helper == .installed
            add(Copy.awakeIndefinitely, #selector(startIndefinite))
                .isEnabled = status.helper == .installed
        }

        menu.addItem(.separator())

        check(Copy.pauseWhenHot, #selector(togglePauseWhenHot), on: settings.pauseWhenHot)
        check(Copy.pauseOnLowBattery, #selector(togglePauseOnLowBattery),
              on: settings.pauseOnLowBattery)
        check(Copy.onlyWhileCharging, #selector(toggleOnlyWhileCharging),
              on: settings.onlyWhileCharging)

        menu.addItem(.separator())

        let login = check(AppInfo.isInApplications ? Copy.launchAtLogin
                                                   : Copy.launchAtLoginNeedsInstall,
                          #selector(toggleLaunchAtLogin),
                          on: SMAppService.mainApp.status == .enabled)
        login.isEnabled = AppInfo.isInApplications

        add(Copy.settings, #selector(openSettings)).keyEquivalent = ","
        menu.addItem(.separator())
        add(Copy.quit, #selector(quit)).keyEquivalent = "q"
        Log.menu.debug("menu opened with \(menu.numberOfItems, privacy: .public) items")
    }

    // MARK: - Building

    @discardableResult
    private func add(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
        return item
    }

    @discardableResult
    private func check(_ title: String, _ action: Selector, on: Bool) -> NSMenuItem {
        let item = add(title, action)
        item.state = on ? .on : .off
        return item
    }

    // MARK: - Doing

    @objc private func startTimed(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        engine.start(.timed(until: Date().addingTimeInterval(seconds)))
    }

    @objc private func startFollow() { engine.start(.follow(started: Date())) }
    @objc private func startIndefinite() { engine.start(.indefinite(started: Date())) }
    @objc private func stop() { engine.stop() }

    @objc private func togglePauseWhenHot() {
        engine.settings.pauseWhenHot.toggle()
        engine.tick()
    }

    @objc private func togglePauseOnLowBattery() {
        engine.settings.pauseOnLowBattery.toggle()
        engine.tick()
    }

    @objc private func toggleOnlyWhileCharging() {
        engine.settings.onlyWhileCharging.toggle()
        engine.tick()
    }

    /// The one password. A cancelled dialog is an answer, not a failure, so it
    /// leaves the menu exactly as it was.
    @objc private func setUp() {
        do {
            try HelperInstaller.install()
        } catch HelperError.cancelled {
            Log.menu.info("set up cancelled")
        } catch {
            Log.menu.error("set up failed: \(String(describing: error), privacy: .public)")
        }
        engine.tick()
    }

    /// The toggle reads back the real status rather than what was asked for:
    /// registering a login item can fail, and a switch that lies about it is
    /// worse than one that snaps back.
    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            Log.menu.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Opens on the room you were sent to. With no rule installed there is
    /// exactly one thing to do in this window, and it is not in General.
    @objc func openSettings() {
        Live.settingsWindow.show(room: engine.status.helper == .missing ? .helper : .general)
    }

    @objc private func quit() {
        engine.stop(reason: .quit)
        NSApp.terminate(nil)
    }
}
