import ServiceManagement
import SwiftUI

/// The whole interface.
///
/// `.menuBarExtraStyle(.menu)` renders this as a real `NSMenu`, so every
/// `Button`, `Toggle` and `Divider` here is a menu item and nothing is drawn
/// by hand.
struct MenuView: View {
    @EnvironmentObject private var engine: Engine
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Text(Copy.statusLine(engine.status, now: Date()))

        if let error = engine.status.error {
            Text(error)
        }

        Divider()

        if engine.status.mode.isActive {
            Button(Copy.stop) { engine.stop() }
        } else {
            ForEach(engine.settings.durations, id: \.self) { seconds in
                Button(Copy.awakeFor(seconds)) {
                    engine.start(.timed(until: Date().addingTimeInterval(seconds)))
                }
            }
            Button(Copy.awakeUntilAgentsFinish) { engine.start(.follow(started: Date())) }
            Button(Copy.awakeIndefinitely) { engine.start(.indefinite(started: Date())) }
        }

        Divider()

        Toggle(Copy.pauseWhenHot, isOn: Binding(
            get: { engine.settings.pauseWhenHot },
            set: { engine.settings.pauseWhenHot = $0 }))
        Toggle(Copy.pauseOnLowBattery, isOn: Binding(
            get: { engine.settings.pauseOnLowBattery },
            set: { engine.settings.pauseOnLowBattery = $0 }))
        Toggle(Copy.onlyWhileCharging, isOn: Binding(
            get: { engine.settings.onlyWhileCharging },
            set: { engine.settings.onlyWhileCharging = $0 }))

        Divider()

        if engine.status.helper == .missing {
            Button(Copy.setUp) { setUp() }
        }
        SettingsLink { Text(Copy.settings) }
        Toggle(Copy.launchAtLogin, isOn: Binding(
            get: { launchAtLogin },
            set: { setLaunchAtLogin($0) }))

        Divider()

        Button(Copy.quit) {
            engine.stop(reason: .quit)
            NSApp.terminate(nil)
        }
    }

    /// The one password. A cancelled dialog is an answer, not a failure, so it
    /// leaves the menu exactly as it was.
    private func setUp() {
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
    private func setLaunchAtLogin(_ wanted: Bool) {
        do {
            if wanted {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.menu.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
