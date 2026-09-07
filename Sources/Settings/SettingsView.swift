import SwiftUI

/// The numbers, in a window, because the menu is for decisions and this is
/// for arithmetic.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine

    var body: some View {
        TabView {
            sessions.tabItem { Label(Copy.roomSessions, systemImage: "clock") }
            agents.tabItem { Label(Copy.roomAgents, systemImage: "text.append") }
            guards.tabItem { Label(Copy.roomGuards, systemImage: "shield") }
            helper.tabItem { Label(Copy.roomHelper, systemImage: "key") }
        }
        .frame(width: 460, height: 340)
    }

    // MARK: - Sessions

    private var sessions: some View {
        Form {
            Stepper(value: hours($engine.settings.indefiniteCap), in: 0...168) {
                LabeledContent(Copy.indefiniteCap, value: Copy.cap(engine.settings.indefiniteCap))
            }
            Stepper(value: minutes($engine.settings.warnBeforeEnd), in: 0...60) {
                LabeledContent(Copy.warnBeforeEnd,
                               value: Copy.duration(engine.settings.warnBeforeEnd))
            }
            Toggle(Copy.notifications, isOn: $engine.settings.notifications)

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
                Button(Copy.addDuration) {
                    engine.settings.durations.append(1800)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Agents

    private var agents: some View {
        Form {
            Stepper(value: minutes($engine.settings.idleTimeout), in: 1...120) {
                LabeledContent(Copy.idleTimeout, value: Copy.duration(engine.settings.idleTimeout))
            }
            Stepper(value: minutes($engine.settings.followGrace), in: 0...120) {
                LabeledContent(Copy.followGrace, value: Copy.duration(engine.settings.followGrace))
            }
            Stepper(value: hours($engine.settings.followCap), in: 1...48) {
                LabeledContent(Copy.followCap, value: Copy.duration(engine.settings.followCap))
            }

            Section(Copy.watchedDirectories) {
                ForEach(Array(engine.settings.watchedDirectories.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField("", text: directory(at: index))
                            .textFieldStyle(.roundedBorder)
                        Button(Copy.remove) {
                            engine.settings.watchedDirectories.remove(at: index)
                        }
                    }
                }
                Button(Copy.addDirectory) {
                    engine.settings.watchedDirectories.append("~/")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Guards

    private var guards: some View {
        Form {
            Section(Copy.heat) {
                Toggle(Copy.pauseWhenHot, isOn: $engine.settings.pauseWhenHot)
                Picker(Copy.thermalPauseLevel, selection: $engine.settings.thermalPauseLevel) {
                    Text(Copy.levelCritical).tag(ThermalLevel.critical)
                    Text(Copy.levelSerious).tag(ThermalLevel.serious)
                }
                .disabled(!engine.settings.pauseWhenHot)
                Stepper(value: seconds($engine.settings.thermalCalm), in: 30...600, step: 30) {
                    LabeledContent(Copy.thermalCalm,
                                   value: Copy.duration(engine.settings.thermalCalm))
                }
                .disabled(!engine.settings.pauseWhenHot)
            }

            Section(Copy.battery) {
                Toggle(Copy.pauseOnLowBattery, isOn: $engine.settings.pauseOnLowBattery)
                Stepper(value: $engine.settings.batteryFloor, in: 5...50) {
                    LabeledContent(Copy.batteryFloor, value: "\(engine.settings.batteryFloor)%")
                }
                .disabled(!engine.settings.pauseOnLowBattery)
                // Resuming at the floor would pause again on the next tick, so
                // the two numbers are kept apart rather than merely warned about.
                Stepper(value: resume, in: 6...100) {
                    LabeledContent(Copy.batteryResume, value: "\(engine.settings.batteryResume)%")
                }
                .disabled(!engine.settings.pauseOnLowBattery)
                Toggle(Copy.onlyWhileCharging, isOn: $engine.settings.onlyWhileCharging)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helper

    private var helper: some View {
        Form {
            LabeledContent(Copy.helperRule,
                           value: engine.status.helper == .installed
                               ? Copy.installed : Copy.notInstalled)
            LabeledContent(Copy.helperGuard,
                           value: GuardAgent.status() ? Copy.installed : Copy.notInstalled)
            if engine.status.helper == .installed {
                Button(Copy.removeHelper) {
                    try? HelperInstaller.uninstall()
                    engine.tick()
                }
            } else {
                Button(Copy.installHelper) {
                    try? HelperInstaller.install()
                    engine.tick()
                }
            }
            Text(Copy.helperExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    // MARK: - Bindings that carry the unit

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
