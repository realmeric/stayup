# stayup kanban

A menu bar app that keeps this MacBook Air awake with the lid closed while an agent is working, and lets it sleep the moment there is nothing left to wait for. One icon in the top bar, a menu with a handful of durations and an "until the agents finish" mode, and two guards that pause the whole thing when the machine gets hot or the battery gets low. Nothing on the Dock, nothing to type.

Written 2026-09-06 against an empty directory, the same night the problem was traced. The short version of why it exists: on 2026-09-03 at 13:47:05 something ran `pmset -a disablesleep 1` on this Mac, and for the next 58 hours the machine never slept once, lid open or closed, because that flag is the one thing in macOS that overrides a lid close. KeepingYouAwake looked like it was doing that job; it never was, it only ever shells out to `caffeinate`, and `caffeinate` holds an idle assertion that a lid close does not consult. The flag was cleared at 22:53 on 2026-09-06 and the lid slept again at 22:54:25. Every fact behind those sentences is in `docs/notes.md`, with the log lines that prove it. This app is the flag, managed properly: raised for a reason, released for a reason, and impossible to leave on by accident.

What this machine has, checked the same night: macOS 26.6.2, Xcode 26.6, Swift 6.3.3, xcodegen 2.46.0. One signing identity, `Apple Development: developer@example.com (CERT_ID)`, team `TEAM_ID`, no Developer ID. A fanless MacBook Air; `pmset -g therm` has never recorded a warning. User `alice`, uid 501, an admin. `/etc/sudoers.d` exists, root, 755, empty of anything ours. `SleepDisabled` reads 0 now. Power settings as found: `sleep 1`, `displaysleep 2` on battery and 10 on AC, `ttyskeepawake 1`, `hibernatemode 3`. Claude Desktop holds a `NoIdleSleepAssertion` named `Electron` the whole time it runs, so idle sleep with the lid open never happens on this Mac anyway; the lid is the only sleep that matters here. 290 transcripts under `~/.claude/projects`, 17 under `~/.codex/sessions`. KeepingYouAwake 1.6.8 is installed and can stay; it does a different job.

How to work the board: one card at a time, top of Ready first. Read the card and the `docs/notes.md` sections it names, do it, run the gate, commit, move the card under Done with its hash. A card is done when every box under Accept is ticked and the gate is green. Something you notice on the way becomes a one-line entry under Backlog, not a change. The executor is expected to be a smaller effort than the planner, so each card names its files, its types, its APIs and the command that proves it; when a card and the platform disagree, the platform wins and the note gets fixed in the same commit.

Legend. Priority: P0 nothing works without it, P1 the feature is wrong or missing a piece, P2 robustness or a visible rough edge, P3 hygiene. Effort: S under half an hour, M under two hours, L half a day. `manual` means `make run` and eyes on the screen or the lid in your hands; those cards commit only what they had to fix. `admin` means the card's manual check asks for your password once.

## Decisions for Meric

Each is written with the recommended option as the default. Strike the other or say so before the card is taken.

- D1, the name. Display name `StayUp`, target, scheme, module and product all `StayUp`, bundle id `com.meric.stayup`. No space in the product name on purpose: Kullanym Notch's `PRODUCT_MODULE_NAME` and `TEST_HOST` hand-wiring exists only because of the space, and this app does not need to pay for that.
- D2, how the flag gets raised. `sudo -n /usr/bin/pmset -a disablesleep 1` from the app, allowed without a password by a four-line rule in `/etc/sudoers.d/stayup` that permits exactly two commands, `disablesleep 1` and `disablesleep 0`, for your user. The rule is installed once by the app through the standard admin prompt. The alternative is a privileged helper registered with `SMAppService` and driven over XPC, which is what a shipped product would do; it costs a second binary, an `SMAuthorizedClients` handshake, an XPC protocol and half a day, to do what the rule does. This is a personal app on one Mac.
- D3, what happens when the flag drops with the lid closed. The app releases the flag and then runs `pmset sleepnow` (no password needed) so the Mac sleeps at once, rather than whenever powerd next re-evaluates the clamshell. This is what "the timer ended" and "the machine is too hot" should mean: asleep now. S-11 checks whether powerd would have slept on its own; the explicit call stays either way, because a behaviour you can predict beats one you have to observe.
- D4, the modes. Timed (30 min, 1 h, 2 h, 5 h, 8 h), Until the agents finish, and Indefinite. Indefinite carries a cap, 24 h by default, changeable in Settings, 0 for none; the whole reason this app exists is a flag nobody turned off, and an uncapped mode is that flag with a nicer icon.
- D5, heat. Pause when `ProcessInfo.thermalState` reaches `.critical`, warn with a notification at `.serious`, and a Settings switch to pause at `.serious` instead. Resume when the state has been `.nominal` or `.fair` for two minutes without interruption. The honest limit: with the lid closed, a pause means the Mac sleeps (D3) and the app stops running with it, so the resume only happens after you open the lid. The card says this in the notification text rather than hiding it.
- D6, battery. Pause when on battery and below 15%, resume on AC or at 20%. A separate switch, "Only while charging", off by default: on, the flag is only ever raised on AC. You run agents on battery overnight sometimes, so the default is the floor, not the switch.
- D7, what "the agents finish" means. A transcript under `~/.claude/projects` or `~/.codex/sessions` was written in the last 3 minutes. Busy is a file growing; there is no status field to read (`docs/notes.md`, "Claude Code's files"). Three minutes rather than the notch's eight seconds because a long tool call is silence, not idleness, and a Mac that dozes off in the middle of an `xcodebuild` is worse than one that waits three minutes too long. The mode has a 5 minute grace after Start so you can start it before the agent, and an 8 hour cap.
- D8, never stuck. Three independent ways the flag comes down without the app's cooperation: the app writes a lease file with an expiry two minutes out and renews it every minute while a session runs; a user LaunchAgent every 60 s clears the flag when it is up and the lease is missing or stale; a LaunchDaemon clears it at every boot. Crash, hang, force-quit and reboot are each covered by a different one of the three.
- D9, quit. Quitting the app releases the flag and removes the lease, always, whatever the mode. Quit means off.
- D10, the look. A menu bar item only, SF Symbols, no Dock icon, no app icon of its own in v1; an icon is a Backlog line. The menu is the whole UI, with a Settings window for the numbers.

## Done

- S-01 · Project skeleton that builds, signs and launches · `02da2c4`
- S-02 · Read the machine · `799e6a9`
- S-03 · The rule that lets the app raise the flag, installed once · `640bcf2`
- S-04 · The guard that drops the flag when the app cannot · `285abab`

## In progress

(empty; one card at a time)

## Ready

### Phase 1: the flag, and every way it comes down

### Phase 2: sessions, guards, and what the agents are doing

#### S-05 · The keeper: a state machine with the clock as an argument

P0 · L · keeper

Files: new `Sources/Keeper/Mode.swift`, `Sources/Keeper/Keeper.swift`, `Sources/Keeper/Settings.swift`, `Tests/KeeperTests.swift`, `Tests/KeeperGuardTests.swift`. Read `docs/notes.md`, "The two sleeps" for what raise and release mean.

Pure code, no IOKit, no shell, no `Date()` inside. Everything that depends on the time takes `now` as an argument.

`Settings.swift`: `struct Settings: Codable, Equatable` with a default beside every field: `durations: [TimeInterval]` (`[1800, 3600, 7200, 18000, 28800]`), `indefiniteCap: TimeInterval` (86400; 0 means none), `thermalPauseLevel: ThermalLevel` (`.critical`), `thermalCalm: TimeInterval` (120), `batteryFloor: Int` (15), `batteryResume: Int` (20), `onlyWhileCharging: Bool` (false), `idleTimeout: TimeInterval` (180), `followGrace: TimeInterval` (300), `followCap: TimeInterval` (28800), `watchedDirectories: [String]` (`["~/.claude/projects", "~/.codex/sessions"]`), `notifications: Bool` (true), `warnBeforeEnd: TimeInterval` (300). `static let defaults = Settings()`.

`Mode.swift`: `enum Mode: Equatable { case off; case timed(until: Date); case follow(started: Date); case indefinite(started: Date) }`.

`Keeper.swift`: `struct Inputs { now: Date; thermal: ThermalLevel; power: PowerReading; lidClosed: Bool; lastAgentWrite: Date? }`, `enum PauseReason { thermal, battery, charging }`, `enum EndReason { timer, agentsIdle, cap, stopped, quit }`, `enum Notice: Equatable { paused(PauseReason), resumed, ended(EndReason), warning(TimeInterval), thermalWarning }`, `enum Effect: Equatable { raise, release(sleepNow: Bool), notify(Notice) }`. `struct Keeper` holds `mode`, `paused: PauseReason?`, `raised: Bool`, `calmSince: Date?`, `warned: Bool`, and `settings`. Three mutating functions, each returning `[Effect]`: `start(_ mode: Mode, inputs:)`, `stop(reason:, inputs:)`, `tick(inputs:)`.

The rules, in the order `tick` applies them. First, is the session over: `.timed` when `now >= until`, reason `.timer`; `.follow` when `now - started > followGrace` and (`lastAgentWrite` is nil or `now - lastAgentWrite > idleTimeout`), reason `.agentsIdle`, or `now - started > followCap`, reason `.cap`; `.indefinite` when the cap is not 0 and `now - started > indefiniteCap`, reason `.cap`. Over means mode becomes `.off`, and if `raised`, `release(sleepNow: lidClosed)` then `notify(.ended(reason))`. Second, the guards, only while a mode is active: `onlyWhileCharging && !power.onAC` pauses with `.charging`; `thermal >= thermalPauseLevel` pauses with `.thermal`; `!power.onAC && power.percent < batteryFloor` pauses with `.battery`. Entering a pause that was not already the pause releases the flag (`sleepNow: lidClosed`) and notifies `.paused(reason)`. A pause lifts when its own condition has cleared: `.charging` when `onAC`; `.battery` when `onAC || percent >= batteryResume`; `.thermal` when `thermal <= .fair` continuously for `thermalCalm`, which `calmSince` tracks (set when the level first reads `.fair` or lower, cleared whenever it reads higher). Lifting notifies `.resumed`. Third, the flag: active and not paused and not raised means `raise`; anything else and raised means release. Fourth, the warning: `.timed` with `until - now <= warnBeforeEnd`, not yet `warned`, and not paused notifies `.warning(until - now)` once. A `thermal == .serious` reading while the pause level is `.critical` notifies `.thermalWarning` once per session. `stop` releases if raised, with `sleepNow: false` when the reason is `.stopped` (you clicked it; you are at the keyboard) and `lidClosed` when it is `.quit`.

`KeeperTests`, each with a fixed `t0` and `Settings.defaults`: start timed 30 min raises; tick at 29 min does nothing but at 25 min sends `.warning(300)` once; tick at 30 min releases with `sleepNow` equal to the lid input and notifies `.ended(.timer)`; follow at t0 with no writes stays raised until 5 min then ends `.agentsIdle`; follow with a write at t0+4m stays alive at t0+6m and ends at t0+7m01s; indefinite ends at 24 h and not at 23 h 59 m, and never with a cap of 0; stop after start releases without sleep. `KeeperGuardTests`: critical pauses with `sleepNow: true` when the lid is closed and the pause does not repeat on the next tick; fair for 119 s does not resume and 120 s does; serious under the default level warns once and does not pause, and pauses under `.serious` as the level; battery 14% on battery pauses, 19% does not resume, 20% does, AC resumes at any percent; `onlyWhileCharging` pauses on battery at 90%.

Accept:

- [ ] `make test` green, the two files above with at least the listed cases.
- [ ] `Keeper.swift` imports only `Foundation`, and `grep -n "Date()" Sources/Keeper` finds nothing.

Commit: `Decide when the flag is up with the clock handed in`

#### S-06 · Sources and the engine that ticks them

P0 · L · engine

Files: new `Sources/Sources/ThermalSource.swift`, `Sources/Sources/PowerSource.swift`, `Sources/Sources/LidSource.swift`, `Sources/Sources/AgentActivity.swift`, `Sources/Sources/FakeSources.swift`, `Sources/Engine/Engine.swift`, `Sources/Engine/Notifier.swift` (a protocol and a logging default; S-09 fills it), `Tests/AgentActivityTests.swift`, `Tests/EngineTests.swift`. Read `docs/notes.md`, "Claude Code's files" and "Reading the machine".

Protocols, one per input, each with a `read()` and an `onChange: (() -> Void)?` the engine sets. `ThermalSource` reads `Thermal.read()` and observes `ProcessInfo.thermalStateDidChangeNotification` through `NotificationCenter`. `PowerSource` reads `Power.read()` and registers `IOPSNotificationCreateRunLoopSource` on the main run loop, the C callback bouncing to `onChange` through an `Unmanaged` context; alternatively poll it on the tick, which is fine at 20 s, and say which was done. `LidSource` reads `Lid.isClosed()` on the tick; there is no cheap notification for it and the tick is enough. `AgentActivity` reads `lastWrite() -> Date?`: for each directory in `settings.watchedDirectories`, expanded with `NSString.expandingTildeInPath`, a `FileManager.enumerator(at:includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])` over every `.jsonl` file, the newest `contentModificationDate` wins. 300 files is a few milliseconds of `stat`; log the count and the elapsed time at debug on each read. A directory that does not exist is skipped silently.

`FakeSources.swift`, in the app target so the manual pass can use them: when `STAYUP_FAKE_THERMAL` is set to `nominal`, `fair`, `serious` or `critical`, `ThermalSource` returns it; `STAYUP_FAKE_POWER` as `ac` or `battery:<percent>`; `STAYUP_FAKE_LID` as `open` or `closed`; `STAYUP_FAKE_AGENT` as `busy` or `idle`. Each is read on every tick so the value can be changed by relaunching, which is all the manual pass needs.

`Engine.swift`: `@MainActor final class Engine: ObservableObject`. Owns a `Keeper`, the four sources, a `FlagWriting`, a `Notifying`, the `Settings`, and a `Timer` at 20 s on the main run loop. `@Published private(set) var status: Status`, `struct Status { mode: Mode; paused: PauseReason?; raised: Bool; endsAt: Date?; helper: HelperStatus; thermal: ThermalLevel; power: PowerReading; lidClosed: Bool; lastAgentWrite: Date? }`. `func start(_ mode: Mode)`, `func stop()`, `func tick()`; `start` refuses with a logged reason when `helper == .missing`. `tick` gathers `Inputs` with `now: Date()` (the one place the clock is read), calls `keeper.tick`, then applies effects in order: `raise` calls the writer and on success `Lease.renew(until: now + 120)`; `release` calls the writer, `Lease.clear()`, and when `sleepNow` runs `Shell.run("/usr/bin/pmset", ["sleepnow"])`; `notify` hands the notice to the notifier. A writer error puts the keeper back to `.off` via `stop(reason: .stopped)` and sets `status.error`. While `raised`, every tick also renews the lease, so the lease stays two minutes ahead of a guard that runs every one. Source `onChange` calls `tick()` immediately. `init` takes every dependency with the real one as the default, so `EngineTests` builds it with the fakes, a `FakeFlagWriter`, a recording notifier, and a temp lease directory, and drives `tick()` by hand.

`EngineTests`: start timed, tick, the fake writer saw `raise` and the lease file exists with an expiry about 120 s ahead; simulate the writer throwing, the status carries the error and the mode is off; a `critical` fake thermal on the next tick makes the writer see `release`, the lease is gone, and the notifier recorded `.paused(.thermal)`.

Accept:

- [ ] `make test` green, `AgentActivityTests` (a temp directory with two `.jsonl` files and a `.txt`, the newer `.jsonl` wins; an empty directory reads nil; a missing directory reads nil) and `EngineTests`.
- [ ] `manual`: `STAYUP_DRY_RUN=1 STAYUP_FAKE_AGENT=busy make run` with a temporary `STAYUP_START=follow` hook (S-07 removes it) logs `raise` under `flag` and renews the lease every 20 s; relaunch with `STAYUP_FAKE_AGENT=idle` and after the 5 min grace the log shows `release` and `ended agentsIdle`.
- [ ] Without `STAYUP_DRY_RUN`, timed 30 min: `pmset -g | grep SleepDisabled` is 1 within 20 s of start, the lease file reads two minutes ahead, and `stop()` returns it to 0 and removes the lease.

Commit: `Tick the machine into the keeper and the keeper into the flag`

### Phase 3: the menu

#### S-07 · The menu bar item

P0 · L · menu

Files: new `Sources/Menu/StatusIcon.swift`, `Sources/Menu/MenuView.swift`, `Sources/Menu/Copy.swift`, edit `Sources/App/Main.swift`, `Sources/App/AppDelegate.swift`, `Tests/CopyTests.swift`. Read `docs/notes.md`, "SwiftUI menu bar".

`Main.swift` becomes `MenuBarExtra { MenuView().environmentObject(engine) } label: { Image(systemName: StatusIcon.name(for: engine.status)) }` with `.menuBarExtraStyle(.menu)`, the engine created once as a `@StateObject` on the `App`. `AppDelegate` keeps the activation policy and the XCTest early return; the engine's `tick()` is called once from `applicationDidFinishLaunching` so the icon is right before the first 20 s.

`StatusIcon.name(for:)`: `moon.zzz` off, `sun.max.fill` raised, `thermometer.high` paused thermal, `battery.25percent` paused battery, `bolt.slash` paused for charging, `exclamationmark.triangle` when the helper is missing. A pure function with a test per state.

`Copy.swift`: the words. `Copy.statusLine(status, now:)`: `Off`, `Awake · 1 h 23 m left` for timed, `Awake · until the agents finish · last write 40 s ago` for follow (`never` before the first write), `Awake · 3 h 12 m` elapsed for indefinite, `Paused · too hot`, `Paused · battery 12%`, `Paused · not charging`, `Set up needed` when the helper is missing. Durations print as `30 m`, `1 h`, `2 h`, `5 h`, `8 h`; anything else `Xh Ym`. Tested.

`MenuView`, top to bottom: the status line as a disabled `Text`; a `Divider`; when off, one `Button` per duration reading `Awake for 30 minutes`, then `Awake until the agents finish`, then `Awake indefinitely`; when active, `Stop` (and while paused, the status line already says why); a `Divider`; `Toggle` items bound to the settings for `Pause when hot`, `Pause on low battery`, `Only while charging`; `Settings…` (`SettingsLink` on macOS 14+, else `NSApp.sendAction(Selector(("showSettingsWindow:")))`); when the helper is missing, `Set up StayUp…` which calls `HelperInstaller.install()` and re-ticks, and when present, nothing (removal lives in Settings, S-08); `Launch at login` as a `Toggle` on `SMAppService.mainApp` (`register()` / `unregister()`, and read `status == .enabled`; a failure logs and the toggle reads back the real status); `Quit` calling `engine.stop(reason: .quit)` then `NSApp.terminate(nil)`. The toggles write through `engine.settings`, which S-08 persists; until then they live for the process.

Accept:

- [ ] `make test` green, `CopyTests` and `StatusIconTests`.
- [ ] `manual`: the icon is `moon.zzz` at launch; `Awake for 30 minutes` turns it to `sun.max.fill` within a second and `pmset -g | grep SleepDisabled` reads 1; `Stop` turns it back and reads 0. `STAYUP_FAKE_THERMAL=critical make run`, start, the icon is `thermometer.high` and the flag reads 0. Quit with a session running: the flag reads 0 and the lease is gone.
- [ ] `Set up StayUp…` shows only while `sudo -n -l` fails (test by temporarily `sudo rm /etc/sudoers.d/stayup`; put it back through the menu item).

Commit: `Put the whole thing in the menu bar`

#### S-08 · Settings, persisted, with a window for the numbers

P1 · M · settings

Files: new `Sources/Settings/SettingsStore.swift`, `Sources/Settings/SettingsView.swift`, `Tests/SettingsStoreTests.swift`, `Tests/SettingsRoomTests.swift`, edit `Sources/Engine/Engine.swift`, `Sources/App/Main.swift`.

`SettingsStore`: one `UserDefaults` key, `settings`, holding the JSON of `Settings`; `load()` returns defaults when the key is missing or fails to decode (and logs the failure), `save(_:)` encodes. Takes a `UserDefaults` in `init` so tests use `UserDefaults(suiteName:)` and `removePersistentDomain` in `tearDown`. The engine loads at init and saves on every change through a `settings` property with a `didSet`.

`SettingsView` under a `Settings { SettingsView().environmentObject(engine) }` scene added beside the `MenuBarExtra`. Four groups in a `Form`. Sessions: the indefinite cap as a `Stepper` in hours (0 reads `no cap`), the warning as minutes. Agents: the idle timeout in minutes, the grace, the cap in hours, and the watched directories as a list of paths with add and remove. Guards: a `Picker` for the thermal level (`Critical`, `Serious`), the calm time in seconds, the battery floor and resume as steppers (resume clamps to floor + 1 or more), and the only-while-charging toggle. Helper: the helper status as a line (`Installed` / `Not installed`), `Install…` or `Remove…`, and the guard agent's status beside it. Every control binds to `engine.settings` fields.

`SettingsRoomTests`, as in Kullanym Notch: uses `Mirror` to walk the fields of `Settings` and fails for any field not in a hand-kept list of placed fields, so a new setting cannot be added without a control.

Accept:

- [ ] `make test` green, `SettingsStoreTests` (round trip, missing reads defaults, garbage reads defaults) and `SettingsRoomTests`.
- [ ] `manual`: change the battery floor to 90, quit, relaunch, it reads 90; `STAYUP_FAKE_POWER=battery:80 make run`, start a session, it pauses at once with `Paused · battery 80%`. Put the floor back to 15.

Commit: `Keep every choice, and give the numbers a window`

#### S-09 · Notifications that say what happened and what happens next

P1 · S · menu

Files: new `Sources/Engine/UserNotifier.swift`, edit `Sources/Engine/Notifier.swift`, `Tests/NoticeCopyTests.swift`.

`UserNotifier: Notifying` on `UNUserNotificationCenter.current()`. Authorization is requested with `[.alert, .sound]` the first time a session starts, not at launch. Each `Notice` becomes a title and a body through `Copy.notice(_:)`, tested: `.paused(.thermal)` → `Paused: too hot` / `The Mac will sleep if the lid is closed. Open it when it has cooled and StayUp resumes.`; `.paused(.battery)` → `Paused: battery low` / `Plug in to resume.`; `.paused(.charging)` → `Paused: not charging` / `Only while charging is on. Plug in to resume.`; `.resumed` → `Awake again` / (empty); `.ended(.timer)` → `Time is up` / `The Mac can sleep now.`; `.ended(.agentsIdle)` → `The agents finished` / `No transcript has been written for 3 minutes. The Mac can sleep now.` (the minutes from settings); `.ended(.cap)` → `Session cap reached` / `StayUp has been on for 24 hours and stopped itself.`; `.warning(300)` → `5 minutes left` / `Start another session from the menu to keep going.`; `.thermalWarning` → `Getting hot` / `Still awake. StayUp pauses at critical; change that in Settings.`. When `settings.notifications` is off the notifier logs and does nothing else. Delivered with `interruptionLevel: .timeSensitive` for the two pauses and the cap, `.active` for the rest.

Accept:

- [ ] `make test` green, `NoticeCopyTests` covering every case of `Notice`.
- [ ] `manual`: the first Start asks for notification permission; `STAYUP_FAKE_THERMAL=critical make run` and Start shows `Paused: too hot` as a banner.

Commit: `Say what happened in a notification, and what to do about it`

#### S-10 · A real app in /Applications, and launch at login

P1 · M · repo · admin

Files: new `scripts/release.sh`, edit `Makefile`, `README.md`. Read `docs/notes.md`, "Building and testing".

`scripts/release.sh`, in the shape of `~/kullanym-notch/scripts/release.sh` with the names changed and the icon checks removed (D10): generate, build Release into `build/`, check the bundle id is `com.meric.stayup`, check `Contents/MacOS/StayUp` exists, `codesign --verify --deep --strict`, check the hardened runtime flag, print the authority, ask `spctl` and say what its answer means; `install` replaces `/Applications/StayUp.app` (`pkill -x StayUp` first, `rm -rf` the old one, `ditto` the new one, `open` it); `zip` leaves `build/StayUp.zip`. `make release`, `make install`, `make zip` call it.

Launch at login only registers for an app in `/Applications` (the note says why), so the `Launch at login` toggle from S-07 gets a guard: when `Bundle.main.bundleURL` is not under `/Applications`, the toggle is disabled and its label reads `Launch at login (run make install first)`.

Accept:

- [ ] `make install` ends with `open /Applications/StayUp.app` and the icon in the menu bar comes from that copy (`ps -o comm -p $(pgrep -x StayUp)` prints the `/Applications` path).
- [ ] `Launch at login` on, log out and in (or reboot): the icon is there without a click, `SMAppService.mainApp.status` reads `.enabled` in the log.
- [ ] Reboot with the flag deliberately left at 1 (`sudo pmset -a disablesleep 1`, then restart): after login `pmset -g | grep SleepDisabled` reads 0, cleared by the LaunchDaemon from S-03.

Commit: `Ship StayUp as an app, not a build directory`

### Phase 4: proving it with the lid

#### S-11 · The lid test, and the three ways down

P0 · M · all · manual · admin

Last on purpose. Everything above is exercised once, with the real lid, the real log and the real flag. Read `docs/notes.md`, "Verifying with the log".

The lid, four times. Off: close the lid two minutes, open, `pmset -g log | grep "Clamshell Sleep" | tail -1` shows a new line for the minute you closed it. Timed 30 min: the same, and no new line appears; the icon is still `sun.max.fill` after opening. Follow, with a Claude Code session actually running in Claude Desktop: close the lid ten minutes, open, no new line, and the status line reads a recent `last write`. Follow again with no agent running: after the 5 min grace, the log shows `ended agentsIdle` and then a `Clamshell Sleep` line within a few seconds of it (D3), so the Mac went to sleep on its own decision. Note the seconds between the release and the sleep line in the card.

The three ways down. Force-quit (`kill -9 $(pgrep -x StayUp)`) during a timed session: within 3 minutes `pmset -g | grep SleepDisabled` reads 0 and the guard log says why. Reboot with a session running: 0 after login. Quit from the menu: 0 at once.

The guards with the fakes, since the Mac cannot be made hot on demand: `STAYUP_FAKE_THERMAL=serious` start, a `Getting hot` banner and the flag still 1; relaunch with `critical`, start, `Paused: too hot` and 0; relaunch with `fair`, start, then two minutes later `Awake again` and 1 (start already awake is the point: this checks the resume path with `calmSince`). `STAYUP_FAKE_POWER=battery:10` start, `Paused: battery low`; `battery:19` still paused; `ac` resumes.

Accept:

- [ ] Off sleeps, timed does not, follow with an agent does not, follow without an agent ends and sleeps; the seconds between release and sleep written here: ___ s.
- [ ] Force-quit, reboot and Quit each bring the flag to 0, with the guard log line quoted here.
- [ ] Every fake path above behaves as written.
- [ ] `docs/notes.md` corrected wherever the machine disagreed, in the same commit.

Commit: one per fix, or none

#### S-12 · README, and the way out

P2 · S · repo

Files: edit `README.md`.

Second person, short. What it does in one paragraph; why `caffeinate` and the apps built on it cannot do this, in one paragraph, with the two log lines from 2026-09-06 23:07:51 and 23:08:02; what it changes on the Mac, exactly (`/etc/sudoers.d/stayup`, the two launchd jobs, the lease file) and how to remove all of it (`Settings › Remove…`, or the four commands by hand); the guards and their defaults; the honest limit that a thermal pause with the lid closed means the Mac sleeps until you open it, and that the app trusts `ProcessInfo.thermalState` rather than a sensor. Build: `make test`, `make run`, `make install`.

Accept:

- [ ] The removal instructions, followed by hand on this Mac, leave `sudo -n -l` failing, both `launchctl print` calls failing, and no lease; then `make install` and set up again.

Commit: `Say what StayUp does to the Mac and how to undo it`

## Backlog

Unranked. Promote by writing a card.

- An icon of its own, drawn with a script the way Kullanym Notch's `scripts/make-icon.swift` does it; D10 left it out of v1.
- A URL scheme, `stayup://start?minutes=60` and `stayup://stop`, so Raycast and Shortcuts can drive it. `CFBundleURLTypes` in the `info:` block and `onOpenURL` on the scene.
- Show the lid state and the lease expiry in the menu under a `Details` line, for the day something looks wrong.
- Watch `~/.claude-<slug>` profiles the way the notch does (`docs/notes.md`, "Claude Code's files"); today only `~/.claude` is on the default list.
- A `Pause` item in the menu that holds the flag down without ending the session, for a hot minute.
- Kullanym Notch could show a small mark while StayUp is raised; the lease file is the signal and needs no protocol.
- A session that runs out while it is paused ends without a word, because the release already happened. S-05 wrote it that way on purpose; whether the ended notice should fire anyway is a question for the day it surprises somebody.
- `Package.swift` in the root points at a `Sources/Stayup` that does not exist and nothing builds through it; xcodegen is the source. Delete it or make it build.
- `ttyskeepawake 1` is set on this Mac and keeps idle sleep off whenever iTerm2 has a live tty. Not this app's business, but the README could mention it.
