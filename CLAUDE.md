# stayup

macOS menu bar app that keeps this MacBook awake with the lid closed while an agent is working, and lets it sleep the moment nothing is left to wait for. It raises the one flag that overrides a lid close, `pmset -a disablesleep 1`, through a scoped sudoers rule, and guarantees the flag comes down again: a lease the app renews, a LaunchAgent that clears a stale one, a LaunchDaemon that clears it at boot. Swift, SwiftUI `MenuBarExtra`, XcodeGen. Kullanym Notch (`~/kullanym-notch`, also yours) is the reference for the build shape and the board; nothing else is copied from it.

Work comes from `KANBAN.md`. Take the top card of Ready, read only that card and the `docs/notes.md` sections it names, do it, run the gate, commit, move the card to Done with its hash. Scope is the card: anything else you notice becomes one line under Backlog, not a change. The cards were written for an executor running at lower effort than the planner, so they name files, types, APIs and the proving command; follow them, and when the platform disagrees with a card, the platform wins and the note is fixed in the same commit.

## Gate

`make test` is the definition of done: `xcodegen generate`, then `xcodebuild test` on the Debug scheme. `make run` builds and launches. `make install` builds Release, verifies the bundle and replaces `/Applications/StayUp.app`. Tests never run `sudo`, `pmset` or `osascript`: `AppDelegate` returns early under XCTest, and everything else takes fakes, temp directories and its own `UserDefaults` suite. Manual checks that need the real flag are marked `manual` on the card; the ones that need your password are marked `admin`.

## Map

- `Sources/App/` `Main`, `AppDelegate`, `Log`, `AppInfo`.
- `Sources/Machine/` reading the Mac: `SleepFlag`, `Lid`, `Power`, `Thermal`, `Shell` (every subprocess goes through it).
- `Sources/Helper/` the privileged side: `HelperInstaller` (the sudoers rule and the boot daemon, one admin prompt), `FlagWriter` (`sudo -n pmset`, the only place the app says `pmset`), `Lease`, `GuardAgent`.
- `Sources/Keeper/` the decision: `Keeper` (a pure state machine, `now` as an argument), `Mode`, `Settings`.
- `Sources/Sources/` the inputs: `ThermalSource`, `PowerSource`, `LidSource`, `AgentActivity`, `FakeSources` (the `STAYUP_FAKE_*` environment hooks).
- `Sources/Engine/` `Engine` (ticks the sources into the keeper and the keeper's effects into the flag, the lease and the notifier), `Notifier`, `UserNotifier`.
- `Sources/Menu/` `MenuView`, `StatusIcon`, `Copy` (every string a person reads).
- `Sources/Settings/` `SettingsStore`, `SettingsView`.
- `Sources/Resources/` `install-helper.sh`, `guard.sh`, the reset daemon plist.
- `Tests/` mirrors `Sources/` by concern.
- `docs/notes.md` the platform's undocumented behaviour, with the log lines that proved it. Keep it true.

## Rules the code does not state

- The flag is raised only with a lease, and released before the lease is cleared. Nothing raises it without `Lease.renew` in the same tick.
- Anything that depends on the time takes `now` as an argument. `Engine.tick` is the one place `Date()` is read.
- A release with the lid closed is followed by `pmset sleepnow`. A release because you clicked Stop is not.
- A guard pause releases the flag; it never ends the session. The session ends on its own terms: timer, idle agents, cap, Stop, Quit.
- Quit is off: release, clear the lease, then terminate.
- Every subprocess goes through `Shell.run` so a test can see what would have run. `sudo` is always `-n`.
- A new setting is a field on `Settings` with a default beside it, a control in `SettingsView`, and a line in `SettingsRoomTests`, which walks the fields out of the type and fails until it is placed.
- The words live in `Copy`; a string literal in a view is a smell.
- Diagnose through the log: `/usr/bin/log stream --predicate 'subsystem == "com.meric.stayup"' --level debug`. The guard writes to `~/Library/Logs/StayUp/guard.log`.

## This machine

macOS 26.6.2, Xcode 26.6, Swift 6.3.3, xcodegen 2.46.0. One signing identity, `Apple Development: developer@example.com (CERT_ID)`, team `TEAM_ID`, no Developer ID. A fanless MacBook Air, user `alice`, uid 501. `SleepDisabled` was found set on 2026-09-06 after 58 hours, cleared by hand at 22:53; `docs/notes.md` "The two sleeps" carries the evidence. Claude Desktop holds an idle assertion whenever it runs, so the lid is the only sleep this Mac ever takes.

## Commits

One card, one commit. Subject in the imperative, sentence case, no prefix, no trailer, naming what is different in the world rather than the diff: `Drop the flag on a timer when the app is not there to do it`. The `meric-writing` skill has the voice. A body only when a choice could have gone the other way.
