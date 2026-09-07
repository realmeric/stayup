# Notes

What the platform does that its documentation does not say, and what was measured on this Mac. Every card in `KANBAN.md` that touches one of these names the section. When the machine disagrees with a line here, the line is wrong: fix it in the same commit.

## The two sleeps

macOS has two separate paths into sleep and they do not share a switch.

Idle sleep is the power management policy: nobody has touched the machine for `sleep` minutes, so it sleeps. An IOKit power assertion (`PreventUserIdleSystemSleep`, `NoIdleSleepAssertion`) tells powerd to stop counting. `caffeinate` holds one; KeepingYouAwake spawns `caffeinate` (its binary contains `spawnCaffeinateTaskForTimeInterval:` and nothing about lids); Claude Desktop holds one named `Electron` for as long as it runs. All of these are visible in `pmset -g assertions`.

Clamshell sleep is a hardware event: the lid sensor closes and powerd puts the machine to sleep. It does not consult idle assertions. Measured on 2026-09-06: KeepingYouAwake created its `caffeinate` assertion at 23:07:51, `pmset -g log` shows it still holding both `PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep` at 23:07:57, and at 23:08:02 the log reads `Entering Sleep state due to 'Clamshell Sleep'`. The assertion was live and the lid closed straight through it. The same happened on AC.

The one thing that overrides clamshell sleep is the `SleepDisabled` flag, set with `pmset -a disablesleep 1`. With it on, the lid closes, the internal display goes dark, and nothing else happens. It overrides idle sleep too, the sleep timer, and the Apple menu's Sleep item. It needs root. It is also what Amphetamine's Closed-Display Mode sets underneath, alongside a `kPMSetClamshellSleepState` call on `IOPMrootDomain` that this app does not make; the flag alone was enough on this Mac for 58 hours, on battery and on AC.

The flag persists. `pmset -a` writes `/Library/Preferences/com.apple.PowerManagement.plist` (`"SleepDisabled" => true`), and a reboot reapplies it. Between 2026-09-03 13:47:05, when that file was last written, and 2026-09-06 22:53, `pmset -g log` shows `Total Sleep/Wakes since boot ... :0` across a boot on 2026-09-05. Whoever set it left no trace: not in `~/.zsh_history`, not in Codex's files, and the unified log does not record `sudo` command lines. That is the failure this app exists to make impossible, and why the flag is never raised without a lease and never left up across a boot ("Never stuck").

Whether powerd sleeps the instant the flag drops while the lid is already closed is not yet measured. powerd logs `EvaluateClamshellSleepState` on power source and desktop-mode changes, so it may. S-11 measures it; the app does not depend on the answer because it calls `pmset sleepnow` itself (D3), which needs no root.

## Reading the machine

`pmset -g` prints the flag as a line of its own above the settings: `·SleepDisabled├──┤├──┤1` in `cat -A`, a leading space, the word, two tabs, the digit. When the flag has never been set the line may be absent; absent is 0. Parse by splitting on whitespace and taking the first two tokens.

`pmset -g batt` prints `Now drawing from 'Battery Power'` or `'AC Power'` and then a line per battery: ` -InternalBattery-0 (id=22806627)	76%; discharging; 13:26 remaining present: true`, also `charging` and `charged`. Prefer IOKit.ps: `IOPSCopyPowerSourcesInfo`, `IOPSGetProvidingPowerSourceType` (`"AC Power"` or `"Battery Power"`), `IOPSCopyPowerSourcesList`, `IOPSGetPowerSourceDescription` with `kIOPSCurrentCapacityKey` and `kIOPSMaxCapacityKey`. Changes arrive through `IOPSNotificationCreateRunLoopSource`, a C callback with a context pointer.

The lid: `AppleClamshellState` on `IOPMrootDomain`, a boolean, `Yes` when closed. From the shell, `ioreg -r -k AppleClamshellState -d 4` prints `"AppleClamshellState" = No` and beside it `"AppleClamshellCausesSleep"`. That second one is not the standing statement it looks like: measured on 2026-09-07, lid open, on battery, flag 0, it read `No`. Read only the first one; the second is powerd's own working state and answers a question nobody here is asking.

Heat: `ProcessInfo.processInfo.thermalState` with `.nominal`, `.fair`, `.serious`, `.critical`, and `ProcessInfo.thermalStateDidChangeNotification`. This Mac is a fanless MacBook Air and `pmset -g therm` reads `No thermal warning level has been recorded` on 2026-09-06, so nothing here has been observed above nominal; the guard is tested with `STAYUP_FAKE_THERMAL`.

Power settings as found on 2026-09-06: `sleep 1`, `displaysleep 2` on battery and 10 on AC, `hibernatemode 3`, `standby 1`, `powernap 1`, `ttyskeepawake 1`. The last one keeps idle sleep off while any tty has a live process, invisible to `pmset -g assertions`; irrelevant to the lid.

powerd's own log lines, for reading later with `/usr/bin/log show --predicate 'subsystem == "com.apple.powerd"'`: `ClamshellState. Closed : 1. ClamshellSleepState: isSleepDisabled : 0`. The `isSleepDisabled` there is the clamshell-specific override (`kPMSetClamshellSleepState`), not the `pmset` flag; it read 0 the whole time the flag was 1.

## Raising the flag without a password

`sudo -n` never prompts: with a rule it runs, without one it exits 1 in a millisecond with `sudo: a password is required` on stderr. `sudo -n -l /usr/bin/pmset -a disablesleep 1` answers whether a rule exists: exit 0 and the command echoed back if allowed, exit 1 otherwise. A GUI app with no tty can run `sudo -n` fine; it is the prompt that needs a tty, and `-n` removes the prompt.

The rule, one line in `/etc/sudoers.d/stayup`, mode 0440, owner `root:wheel`:

```
alice ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

Arguments in a sudoers command are matched exactly, so `pmset -a disablesleep 1` is allowed and `pmset -a sleep 0` is not. Check any candidate with `visudo -cf <file>` before installing it; a syntax error in `sudoers.d` can lock every `sudo` on the machine. `visudo -cf` on a file you own needs no root.

The admin prompt: `/usr/bin/osascript -e 'do shell script "/bin/sh \"/path/to/install-helper.sh\" \"alice\"" with administrator privileges'`. The dialog names the calling app. A cancelled dialog exits with `-128` and `User canceled.` on stderr. The script runs as root with a minimal environment, so every path in it is absolute.

`pmset sleepnow` needs no root and puts the machine to sleep at once, from any process.

## Never stuck

Three mechanisms, each covering a failure the others do not.

The lease: `~/Library/Application Support/StayUp/lease`, one line, an ISO-8601 UTC expiry (`2026-09-07T01:23:45Z`), written atomically. The app renews it to two minutes ahead on every 20 s tick while the flag is raised, and removes it on release. It is a claim with a deadline: a reader who finds it in the past knows the app stopped renewing, whatever the reason.

The guard: a user LaunchAgent, `com.meric.stayup.guard`, every 60 s, running `~/Library/Application Support/StayUp/guard.sh`. If the flag is 1 and the lease is missing or expired, `sudo -n /usr/bin/pmset -a disablesleep 0`. It covers a crash, a hang and a force-quit. It uses the same sudoers rule as the app. It never calls `sleepnow`. `date -j -f "%Y-%m-%dT%H:%M:%SZ" -u "$stamp" +%s` parses the lease in a script with nothing but `/bin` and `/usr/bin`.

The boot reset: a LaunchDaemon, `/Library/LaunchDaemons/com.meric.stayup.reset.plist`, `RunAtLoad`, running `/usr/bin/pmset -a disablesleep 0` as root at every boot. It covers a flag that was up when the machine went down, whatever put it there. Installed by the same admin step as the rule.

launchd: `launchctl bootstrap gui/501 <plist>` for the agent, `launchctl bootstrap system <plist>` for the daemon (root), `bootout` to remove, `launchctl print gui/501/<label>` to check. `bootstrap` of a label already loaded fails; `bootout` first, ignoring its failure. A LaunchDaemon plist must be owned by `root:wheel`, mode 644, or launchd refuses it.

Login items: `SMAppService.mainApp.register()` only takes an app in `/Applications`; from a build directory it reports success and nothing launches. `make install` puts it there.

## Claude Code's files

Config directory: `~/.claude`, or `~/.claude-<slug>` for a profile run with `CLAUDE_CONFIG_DIR`. A transcript is `<config>/projects/<cwd with every character outside [A-Za-z0-9-] replaced by "-">/<sessionId>.jsonl`; subagents write beside it under `subagents/`. Records carry no status field on this version (2.1.261), so whether a session is working is read from its transcript growing: the file's modification date is the last moment the agent did something. On 2026-09-06 there were 290 files under `~/.claude/projects`, 312 MB; enumerating their modification dates is a `stat` each and a few milliseconds in all. The agent is silent during a long tool call (a build, a test run, a subagent), which is why this app calls it idle only after 3 minutes without a write, not the 8 seconds a live indicator would use.

Codex: `~/.codex/sessions/**/*.jsonl`, the same shape of signal.

Claude Desktop runs its Claude Code sessions from the app, so the transcripts are the only footprint; there is no `claude` process to watch.

## SwiftUI menu bar

`MenuBarExtra(content:label:)` with `.menuBarExtraStyle(.menu)` renders a real `NSMenu`: `Button`, `Toggle`, `Divider`, disabled `Text` all become items, and the label's `Image(systemName:)` is the icon. The label view is re-evaluated when the `@Published` it reads changes, so an icon that follows state is a function of the status, nothing more. `LSUIElement: true` in `Info.plist` keeps the app off the Dock; `NSApp.setActivationPolicy(.accessory)` in the delegate does the same at runtime and is kept so the behaviour does not depend on the plist alone. The `Settings` scene opens through `SettingsLink` on macOS 14 and later.

## Building and testing

The unit test bundle is hosted by the app, so `xcodebuild test` runs `applicationDidFinishLaunching` for real. The delegate returns early when `XCTestConfigurationFilePath` is set, or every test run would tick the engine and touch `sudo`. Tests use fakes, temp directories and their own `UserDefaults` suites; nothing under `Tests/` may run `sudo`, `pmset` or `osascript`.

Signing: `Apple Development: developer@example.com (CERT_ID)`, the only identity here. The team is the certificate's OU, `TEAM_ID`; the string in parentheses is the certificate's own name and xcodebuild rejects it as a team. Hardened runtime on, sandbox off: the app runs `sudo` and `osascript` and reads under `~/.claude`, none of which a sandboxed process can do. Ad-hoc signing would also work for this app, since it keeps nothing in the keychain, but the same identity as Kullanym Notch costs nothing and keeps `make install` builds consistent.

xcodegen 2.46.0, `project.yml` is the source and `*.xcodeproj` is ignored. `SWIFT_VERSION: "5.0"` with `SWIFT_STRICT_CONCURRENCY: minimal` keeps Swift 6.3's strict concurrency from arguing with AppKit callbacks; the engine is `@MainActor` and everything else is plain.

Logs: the app has no window, so `/usr/bin/log stream --predicate 'subsystem == "com.meric.stayup"' --level debug`. `/usr/bin/log`, because zsh has a builtin called `log`.

## Verifying with the log

`pmset -g log` goes back about a week (on 2026-09-06 it began at 2026-08-30). Three greps answer three questions.

Did the lid sleep the machine: `pmset -g log | grep "Clamshell Sleep" | tail -3`. A line with a timestamp in the window the lid was closed means it slept.

Has it slept at all since boot: `pmset -g log | grep "Total Sleep/Wakes"`.

Who is holding an idle assertion right now: `pmset -g assertions`, the block under `Listed by owning process`. Not relevant to the lid, but the first place anyone looks, so know what it does and does not show.

And the flag itself: `pmset -g | grep SleepDisabled`.
