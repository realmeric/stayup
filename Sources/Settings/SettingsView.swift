import AppKit
import SwiftUI

/// The settings window: a sidebar of rooms, and one room on screen at a time.
///
/// A shell around `SettingsRoomView`, which is where the settings actually are.
/// Split because a `NavigationSplitView` will not draw outside a real window,
/// so the rooms could not otherwise be looked at except by running the app.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine
    @State private var room: SettingsRoom

    /// The room it opens on. Setting up lands on Helper, because that is the
    /// one room somebody is sent to rather than goes looking for.
    init(room: SettingsRoom = .general) {
        _room = State(initialValue: room)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsRoom.allCases, selection: Binding(
                get: { room },
                set: { room = $0 ?? room }
            )) { room in
                Label(room.title, systemImage: room.symbol).tag(room)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 164, max: 210)
        } detail: {
            SettingsRoomView(room: room, engine: engine)
                .navigationTitle(room.title)
        }
        .frame(minWidth: SettingsView.width, minHeight: SettingsView.height)
    }

    /// The narrowest the sidebar and the widest room fit side by side.
    static let width: CGFloat = 640
    /// Tall enough that the longest room is one scroll rather than three.
    static let height: CGFloat = 520
}

struct SettingsRoomView: View {
    let room: SettingsRoom
    @ObservedObject var engine: Engine
    @State private var shortcutRefused = false

    var body: some View {
        Form {
            switch room {
            case .general: general
            case .sessions: sessions
            case .agents: agents
            case .guards: guards
            case .appearance: appearance
            case .helper: helper
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var general: some View {
        Group {
            Section {
                Picker(Copy.quickStart, selection: quickKind) {
                    Text(Copy.quickTimed).tag(QuickKind.timed)
                    Text(Copy.quickFollow).tag(QuickKind.follow)
                    Text(Copy.quickIndefinite).tag(QuickKind.indefinite)
                }
                if case .timed = engine.settings.quickStart {
                    Stepper(value: quickMinutes, in: 5...1440, step: 5) {
                        row(Copy.quickDuration, Copy.duration(quickSeconds))
                    }
                }
                Toggle(Copy.startOnLaunch, isOn: $engine.settings.startOnLaunch)
            } header: {
                Text(Copy.quickStartSection)
            } footer: {
                Text(Copy.quickStartExplanation).font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Toggle(Copy.shortcutEnabled, isOn: $engine.settings.hotkeyEnabled)
                LabeledContent(Copy.shortcut) {
                    HotkeyRecorder(hotkey: Binding(
                        get: { engine.settings.hotkey },
                        set: { engine.settings.hotkey = $0 }
                    ), isEnabled: engine.settings.hotkeyEnabled)
                    .frame(width: 132, height: 24)
                }
                if shortcutRefused {
                    Text(Copy.shortcutTaken).font(.footnote).foregroundStyle(.orange)
                }
            } header: {
                Text(Copy.shortcut)
            } footer: {
                Text(Copy.shortcutExplanation).font(.footnote).foregroundStyle(.secondary)
            }
            .onChange(of: engine.settings.hotkey) { _, _ in
                shortcutRefused = !HotkeyCenter.shared.adopt(engine.settings.hotkey,
                                                             enabled: engine.settings.hotkeyEnabled)
            }

            Section {
                Toggle(Copy.notifications, isOn: $engine.settings.notifications)
                Toggle(AppInfo.isInApplications ? Copy.launchAtLogin
                                                : Copy.launchAtLoginNeedsInstall,
                       isOn: launchAtLogin)
                    .disabled(!AppInfo.isInApplications)
            }
        }
    }

    // MARK: - Sessions

    private var sessions: some View {
        Group {
            Section {
                Stepper(value: hours($engine.settings.indefiniteCap), in: 0...168) {
                    row(Copy.indefiniteCap, Copy.cap(engine.settings.indefiniteCap))
                }
                Stepper(value: minutes($engine.settings.warnBeforeEnd), in: 0...60) {
                    row(Copy.warnBeforeEnd, Copy.duration(engine.settings.warnBeforeEnd))
                }
            }

            Section {
                Toggle(Copy.keepScreenOn, isOn: $engine.settings.keepScreenOn)
            } header: {
                Text(Copy.screen)
            } footer: {
                Text(Copy.keepScreenOnExplanation).font(.footnote).foregroundStyle(.secondary)
            }

            Section(Copy.durations) {
                ForEach(Array(engine.settings.durations.enumerated()), id: \.offset) { index, seconds in
                    HStack {
                        Stepper(value: duration(at: index), in: 5...1440, step: 5) {
                            Text(Copy.spelled(seconds))
                        }
                        Button(Copy.remove) { engine.settings.durations.remove(at: index) }
                            .disabled(engine.settings.durations.count == 1)
                    }
                }
                Button(Copy.addDuration) { engine.settings.durations.append(1800) }
            }
        }
    }

    // MARK: - Agents

    private var agents: some View {
        Group {
            Section {
                Stepper(value: minutes($engine.settings.idleTimeout), in: 1...120) {
                    row(Copy.idleTimeout, Copy.duration(engine.settings.idleTimeout))
                }
                Stepper(value: minutes($engine.settings.followGrace), in: 0...120) {
                    row(Copy.followGrace, Copy.duration(engine.settings.followGrace))
                }
                Stepper(value: hours($engine.settings.followCap), in: 1...48) {
                    row(Copy.followCap, Copy.duration(engine.settings.followCap))
                }
            }

            Section(Copy.watchedDirectories) {
                ForEach(Array(engine.settings.watchedDirectories.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        // `labelsHidden` on purpose: in a grouped `Form` a
                        // field with an empty label still claims the label
                        // column, which pushes the path into the narrow value
                        // column on the right and right-aligns the text in it.
                        TextField(Copy.directoryPlaceholder, text: directory(at: index))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        Button(Copy.remove) {
                            engine.settings.watchedDirectories.remove(at: index)
                        }
                    }
                }
                Button(Copy.addDirectory) { engine.settings.watchedDirectories.append("~/") }
            }
        }
    }

    // MARK: - Guards

    private var guards: some View {
        Group {
            Section(Copy.heat) {
                Toggle(Copy.pauseWhenHot, isOn: $engine.settings.pauseWhenHot)
                Picker(Copy.thermalPauseLevel, selection: $engine.settings.thermalPauseLevel) {
                    Text(Copy.levelCritical).tag(ThermalLevel.critical)
                    Text(Copy.levelSerious).tag(ThermalLevel.serious)
                }
                .disabled(!engine.settings.pauseWhenHot)
                Stepper(value: seconds($engine.settings.thermalCalm), in: 30...600, step: 30) {
                    row(Copy.thermalCalm, Copy.duration(engine.settings.thermalCalm))
                }
                .disabled(!engine.settings.pauseWhenHot)
            }

            Section(Copy.battery) {
                Toggle(Copy.pauseOnLowBattery, isOn: $engine.settings.pauseOnLowBattery)
                Stepper(value: $engine.settings.batteryFloor, in: 5...50) {
                    row(Copy.batteryFloor, "\(engine.settings.batteryFloor)%")
                }
                .disabled(!engine.settings.pauseOnLowBattery)
                // Resuming at the floor would pause again on the next tick, so
                // the two numbers are kept apart rather than merely warned about.
                Stepper(value: resume, in: 6...100) {
                    row(Copy.batteryResume, "\(engine.settings.batteryResume)%")
                }
                .disabled(!engine.settings.pauseOnLowBattery)
                Toggle(Copy.onlyWhileCharging, isOn: $engine.settings.onlyWhileCharging)
            }
        }
    }

    // MARK: - Appearance

    private var appearance: some View {
        Group {
            Section {
                Picker(Copy.iconStyle, selection: $engine.settings.iconStyle) {
                    ForEach(IconStyle.allCases.filter(\.isDrawable)) { style in
                        Label(style.title, systemImage: style.filled).tag(style)
                    }
                }
                .pickerStyle(.menu)
                ColorPicker(Copy.awakeColor, selection: colorBinding(\.awakeColor),
                            supportsOpacity: false)
                ColorPicker(Copy.idleColor, selection: colorBinding(\.idleColor),
                            supportsOpacity: false)
                Button(Copy.restoreColors) {
                    engine.settings.awakeColor = Palette.defaultAwake
                    engine.settings.idleColor = Palette.defaultIdle
                }
            } header: {
                Text(Copy.menuBarSection)
            } footer: {
                Text(Copy.appearanceExplanation).font(.footnote).foregroundStyle(.secondary)
            }

            Section(Copy.preview) {
                HStack(spacing: 28) {
                    sample(Copy.previewOff, filled: false,
                           color: engine.settings.idleColor, dimmed: false)
                    sample(Copy.previewAwake, filled: true,
                           color: engine.settings.awakeColor, dimmed: false)
                    sample(Copy.previewPaused, filled: false,
                           color: engine.settings.awakeColor, dimmed: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
    }

    /// The three states side by side, drawn the way the menu bar draws them,
    /// so a colour is chosen against what it will actually look like.
    private func sample(_ title: String, filled: Bool, color: String, dimmed: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: engine.settings.iconStyle.name(filled: filled))
                .font(.system(size: 17))
                .foregroundStyle(Color(hexString: color)
                    .opacity(dimmed ? Palette.pausedOpacity : 1))
                .frame(height: 22)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper

    private var helper: some View {
        Group {
            Section {
                LabeledContent(Copy.helperRule,
                               value: engine.status.helper == .installed
                                   ? Copy.installed : Copy.notInstalled)
                row(Copy.helperGuard, GuardAgent.status() ? Copy.installed : Copy.notInstalled)
                if engine.status.helper == .installed {
                    Button(Copy.removeHelper, role: .destructive) {
                        try? HelperInstaller.uninstall()
                        engine.tick()
                    }
                } else {
                    Button(Copy.installHelper) {
                        try? HelperInstaller.install()
                        engine.tick()
                    }
                }
            } footer: {
                Text(Copy.helperExplanation).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    /// A label on the left and its value on the right.
    ///
    /// `LabeledContent` does this on its own everywhere except inside a
    /// `Stepper`, whose label closure gives it only as much width as it asks
    /// for; the value then sits against the label and the column of numbers
    /// down the right of the form breaks.
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(.secondary)
        }
    }

    // MARK: - Bindings that carry the unit

    private enum QuickKind: Hashable { case timed, follow, indefinite }

    private var quickSeconds: TimeInterval {
        if case .timed(let seconds) = engine.settings.quickStart { return seconds }
        return 3600
    }

    private var quickKind: Binding<QuickKind> {
        Binding(get: {
            switch engine.settings.quickStart {
            case .timed: return .timed
            case .follow: return .follow
            case .indefinite: return .indefinite
            }
        }, set: { kind in
            switch kind {
            case .timed: engine.settings.quickStart = .timed(quickSeconds)
            case .follow: engine.settings.quickStart = .follow
            case .indefinite: engine.settings.quickStart = .indefinite
            }
        })
    }

    private var quickMinutes: Binding<Int> {
        Binding(get: { Int(quickSeconds / 60) },
                set: { engine.settings.quickStart = .timed(TimeInterval($0) * 60) })
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(get: { SMAppServiceBridge.isEnabled },
                set: { SMAppServiceBridge.set($0) })
    }

    private func colorBinding(_ key: WritableKeyPath<Settings, String>) -> Binding<Color> {
        Binding(get: { Color(hexString: engine.settings[keyPath: key]) },
                set: { engine.settings[keyPath: key] = $0.hexString })
    }

    private func hours(_ source: Binding<TimeInterval>) -> Binding<Int> {
        Binding(get: { Int(source.wrappedValue / 3600) },
                set: { source.wrappedValue = TimeInterval($0) * 3600 })
    }

    private func minutes(_ source: Binding<TimeInterval>) -> Binding<Int> {
        Binding(get: { Int(source.wrappedValue / 60) },
                set: { source.wrappedValue = TimeInterval($0) * 60 })
    }

    private func seconds(_ source: Binding<TimeInterval>) -> Binding<Int> {
        Binding(get: { Int(source.wrappedValue) },
                set: { source.wrappedValue = TimeInterval($0) })
    }

    private func duration(at index: Int) -> Binding<Int> {
        Binding(get: { Int(engine.settings.durations[index] / 60) },
                set: { engine.settings.durations[index] = TimeInterval($0) * 60 })
    }

    private func directory(at index: Int) -> Binding<String> {
        Binding(get: { engine.settings.watchedDirectories[index] },
                set: { engine.settings.watchedDirectories[index] = $0 })
    }

    private var resume: Binding<Int> {
        Binding(get: { engine.settings.batteryResume },
                set: { engine.settings.batteryResume = max($0, engine.settings.batteryFloor + 1) })
    }
}
