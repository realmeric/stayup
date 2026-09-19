# Notes

What the platform does that its documentation does not say, and what was measured on this Mac. Every card in `KANBAN.md` that touches one of these names the section. When the machine disagrees with a line here, the line is wrong: fix it in the same commit.

## The two sleeps

macOS has two separate paths into sleep and they do not share a switch.

Idle sleep is the power management policy: nobody has touched the machine for `sleep` minutes, so it sleeps. An IOKit power assertion (`PreventUserIdleSystemSleep`, `NoIdleSleepAssertion`) tells powerd to stop counting. `caffeinate` holds one; KeepingYouAwake spawns `caffeinate` (its binary contains `spawnCaffeinateTaskForTimeInterval:` and nothing about lids); Claude Desktop holds one named `Electron` for as long as it runs. All of these are visible in `pmset -g assertions`.

Clamshell sleep is a hardware event: the lid sensor closes and powerd puts the machine to sleep. It does not consult idle assertions. Measured on 2026-09-06: KeepingYouAwake created its `caffeinate` assertion at 23:07:51, `pmset -g log` shows it still holding both `PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep` at 23:07:57, and at 23:08:02 the log reads `Entering Sleep state due to 'Clamshell Sleep'`. The assertion was live and the lid closed straight through it. The same happened on AC.

The one thing that overrides clamshell sleep is the `SleepDisabled` flag, set with `pmset -a disablesleep 1`. With it on, the lid closes, the internal display goes dark, and nothing else happens. It overrides idle sleep too, the sleep timer, and the Apple menu's Sleep item. It needs root. It is also what Amphetamine's Closed-Display Mode sets underneath, alongside a `kPMSetClamshellSleepState` call on `IOPMrootDomain` that this app does not make; the flag alone was enough on this Mac for 58 hours, on battery and on AC.

The flag persists. `pmset -a` writes `/Library/Preferences/com.apple.PowerManagement.plist` (`"SleepDisabled" => true`), and a reboot reapplies it. Between 2026-09-03 13:47:05, when that file was last written, and 2026-09-06 22:53, `pmset -g log` shows `Total Sleep/Wakes since boot ... :0` across a boot on 2026-09-05. Who set it, found on 2026-09-07: Vorssaint (`com.vorssaint.utils`), whose Keep awake feature has a closed-lid option that runs `sudo -n /usr/bin/pmset disablesleep 1` through `/etc/sudoers.d/vorssaint-clamshell`, a rule this Mac still carries, written 2026-08-29 20:09:51, granting `pmset disablesleep 1` and `pmset disablesleep 0` (no `-a`) without a password. That is why no shell history and no prompt recorded it. The unified log has Vorssaint (pid 1577) alive at 13:46:48 on 2026-09-03, seventeen seconds before the flag was written, and `termination reported by launchd (0, 0, 0)` at 21:46:31 the same evening: a clean quit that did not restore the flag. Its only recovery for a flag left up is a `UserDefaults` marker checked on its next launch, and there was no next launch: the app, its preferences and its Application Support folder are gone from this Mac, and only the sudoers rule survived. Between 2026-08-31 and 2026-09-03 11:18 the log shows 22 clamshell sleeps, so on the days before it did restore the flag on time. That quit is the failure this app exists to make impossible, and why the flag is never raised without a lease and never left up across a boot ("Never stuck"). StayUp does not touch the Vorssaint rule; removing it is a line for Meric, `sudo rm /etc/sudoers.d/vorssaint-clamshell`.

There is a third timer that neither of those switches touches: the display's. powerd blanks the screen after `displaysleep` minutes, 2 on battery and 10 on AC as this Mac is set, and `SleepDisabled` has nothing to say about it - measured on 2026-09-08 with the flag reading 1 and the app holding a session, `pmset -g assertions` showed `PreventUserIdleDisplaySleep 0` and the screen went dark on its schedule while the machine stayed up. That is not the flag failing; `pmset -g log` has no `Entering Sleep state` line after the flag went up, and the last `Clamshell Sleep` before it was 2026-09-07 18:24:34. Keeping the screen up is a separate claim, a `PreventUserIdleDisplaySleep` assertion through `IOPMAssertionCreateWithName`, the same one `caffeinate -d` takes. It needs no root and it dies with the process, so unlike the flag there is nothing to leave behind and nothing for the guard to clear. StayUp takes it alongside the flag when `keepScreenOn` is on, and it is named in `pmset -g assertions` so the answer to "what is holding my screen on" is in the place people look. It does not stop the screen locking or the screen saver, which are their own settings.

Whether powerd sleeps the instant the flag drops while the lid is already closed is not yet measured. powerd logs `EvaluateClamshellSleepState` on power source and desktop-mode changes, so it may. S-11 measures it; the app does not depend on the answer because it calls `pmset sleepnow` itself (D3), which needs no root.

## Reading the machine

`pmset -g` prints the flag as a line of its own above the settings: `·SleepDisabled├──┤├──┤1` in `cat -A`, a leading space, the word, two tabs, the digit. When the flag has never been set the line may be absent; absent is 0. Parse by splitting on whitespace and taking the first two tokens.

`pmset -g batt` prints `Now drawing from 'Battery Power'` or `'AC Power'` and then a line per battery: ` -InternalBattery-0 (id=22806627)	76%; discharging; 13:26 remaining present: true`, also `charging` and `charged`. Prefer IOKit.ps: `IOPSCopyPowerSourcesInfo`, `IOPSGetProvidingPowerSourceType` (`"AC Power"` or `"Battery Power"`), `IOPSCopyPowerSourcesList`, `IOPSGetPowerSourceDescription` with `kIOPSCurrentCapacityKey` and `kIOPSMaxCapacityKey`. Changes arrive through `IOPSNotificationCreateRunLoopSource`, a C callback with a context pointer.

The lid: `AppleClamshellState` on `IOPMrootDomain`, a boolean, `Yes` when closed. From the shell, `ioreg -r -k AppleClamshellState -d 4` prints `"AppleClamshellState" = No` and beside it `"AppleClamshellCausesSleep"`. That second one is not the standing statement it looks like: measured on 2026-09-07, lid open, on battery, flag 0, it read `No`. Read only the first one; the second is powerd's own working state and answers a question nobody here is asking.

Heat: `ProcessInfo.processInfo.thermalState` with `.nominal`, `.fair`, `.serious`, `.critical`, and `ProcessInfo.thermalStateDidChangeNotification`. This Mac is a fanless MacBook Air and `pmset -g therm` reads `No thermal warning level has been recorded` on 2026-09-06, so nothing here has been observed above nominal; the guard is tested with `STAYUP_FAKE_THERMAL`.

Power settings as found on 2026-09-06: `sleep 1`, `displaysleep 2` on battery and 10 on AC, `hibernatemode 3`, `standby 1`, `powernap 1`, `ttyskeepawake 1`. The last one keeps idle sleep off while any tty has a live process, invisible to `pmset -g assertions`; irrelevant to the lid.

powerd's own log lines, for reading later with `/usr/bin/log show --predicate 'subsystem == "com.apple.powerd"'`: `ClamshellState. Closed : 1. ClamshellSleepState: isSleepDisabled : 0`. The `isSleepDisabled` there is the clamshell-specific override (`kPMSetClamshellSleepState`), not the `pmset` flag; it read 0 the whole time the flag was 1.

## Raising the flag without a password

`sudo -n` never prompts: with a rule it runs, without one it exits 1 in a millisecond with `sudo: a password is required` on stderr. A GUI app with no tty can run `sudo -n` fine; it is the prompt that needs a tty, and `-n` removes the prompt.

Whether the rule works is answered by using it, not by asking. `sudo -n -l /usr/bin/pmset -a disablesleep 1` lists the rule (exit 0, the command echoed back), but Vorssaint's issue #269 collected Macs on which `-l` said yes and the real call still prompted, so the app probes with the real call: `sudo -n /usr/bin/pmset -a disablesleep <v>` where `v` is the value the app wants right now (1 while a session holds the flag, 0 otherwise). Re-applying the wanted value changes nothing and cannot resurrect a stale 1 over a clear the guard just made, which is the race a probe that re-applies the value it read has to serialize against.

The rule, one line in `/etc/sudoers.d/stayup`, mode 0440, owner `root:wheel`, the user named by uid:

```
#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

`#uid` is sudoers' own user spec (`User ::= '!'* #user-ID` in the grammar, sudo 1.9.17p2). A short name is free-form text (on an SSO-enrolled Mac it can be `name@company.com`, Vorssaint's #915), and it would have to be sanitized against sudoers and the shell both; digits read the same to every interpreter. `visudo -cf` accepts the form - and accepts far too much beside it, because `#` followed by anything that is not a digit is a comment, and a comment parses. `#alice ALL=(root) NOPASSWD: ...` installs cleanly, grants nothing, and leaves the app believing it is set up. `install-helper.sh` refuses a non-numeric argument before it writes anything. Arguments in a sudoers command are matched exactly, so `pmset -a disablesleep 1` is allowed and `pmset -a sleep 0` is not, and the rule and the call must agree on `-a`. Check any candidate with `visudo -cf <file>` before installing it; a syntax error in `sudoers.d` can lock every `sudo` on the machine. `visudo -cf` on a file you own needs no root.

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

## The menu bar item

`MenuBarExtra` cannot tell a left click from a right one. Both open the content, and there is no gesture left over, so an icon whose left button is meant to *do* something has to be an `NSStatusItem` built by hand. The button takes both buttons through one action with `sendAction(on: [.leftMouseUp, .rightMouseUp])` and asks `NSApp.currentEvent` which arrived; control-click reads as a right click, because macOS has said so since before there were two buttons.

The mask matters and is not symmetric. `sendAction(on: [.leftMouseUp, .rightMouseUp])` is what everyone writes and the right click never reaches the action at all: measured 2026-09-07, no action, no log line, nothing. `[.leftMouseUp, .rightMouseDown]` delivers both. `NSApp.currentEvent` inside the action can then read as either `.rightMouseDown` or `.rightMouseUp` depending on how far AppKit has got, so the gesture test accepts both.

The menu is assigned for the length of one click and taken away again: an `NSStatusItem` with `menu` set permanently stops sending its action altogether, and the left click quietly stops working. `item.menu = menu; button.performClick(nil); item.menu = nil`.

A menu on screen is invisible to screen capture. `screencapture`, and the screenshot tools built on the same API, return the desktop without it, so an open menu looks exactly like a menu that never opened. Two hours went into a bug that was not there. Prove a menu by driving it - type-select a letter, press Return, watch the flag - or by `menuNeedsUpdate` logging the item count.

The icon is not a template image. A template is repainted by the menu bar in black or white and a chosen colour would never survive it, so the symbol is drawn into an `NSImage` and filled `.sourceAtop` with the colour, `isTemplate = false`. The cost is that macOS no longer inverts it for a light menu bar, which is why the resting colour ships white and the awake colour is a hue that reads on both.

`LSUIElement: true` in `Info.plist` keeps the app off the Dock; `NSApp.setActivationPolicy(.accessory)` in the delegate does the same at runtime and is kept so the behaviour does not depend on the plist alone. It also keeps the app out of the list computer-use can drive, which is why the click routing is a pure function with a test rather than something a robot proves by clicking.

The settings window is an `NSWindow` around an `NSHostingView`, not a SwiftUI `Settings` scene. `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` is the documented-by-folklore way to open one and it answers `true`; measured on 2026-09-07, with `Settings` as the app's only scene it then made no window at all - not immediately, not two seconds later, and not with the activation policy raised to `.regular` first. `NSApp.windows` held only `NSStatusBarWindow` throughout. So the app has no SwiftUI scene and no `App` at all: `@main` is a plain `NSApplication.shared.run()`.

A window from an accessory app opens behind whatever you were working in. `makeKeyAndOrderFront` plus `activate` is not enough; `orderFrontRegardless` is the part that does not ask.

## The global shortcut

Carbon's `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitorForEvents`. The monitor needs Accessibility permission and sees every keystroke on the Mac, which is an enormous thing to ask for one shortcut; Carbon asks for nothing and only ever hears the combination it registered. The handler is installed once on `GetEventDispatcherTarget()` and fires on the main thread.

The combination is stored as Carbon's own numbers (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`, and a virtual key code) rather than `NSEvent.ModifierFlags`, because Carbon is what registers it and a translation kept in a settings file is one that can go stale. A key code is a position on the keyboard, not a letter, so the recorder asks the current layout what the key produces through `UCKeyTranslate`: on a Turkish-Q keyboard a table baked into the app would name the wrong letters.

`RegisterEventHotKey` returns a non-zero status when something else already owns the combination, which is the only failure worth showing: the settings window says so rather than leaving a dead switch. The recorder unregisters the current shortcut while it is recording, or pressing the existing one fires the app instead of being caught.

## SwiftUI menu bar

`MenuBarExtra(content:label:)` with `.menuBarExtraStyle(.menu)` renders a real `NSMenu` and was what this app used until the left button had to mean something. Kept here because it is the right answer for an icon that only ever opens a list, and because `SettingsLink` works inside it where the AppKit menu has to send `showSettingsWindow:` by name.

## Building and testing

The unit test bundle is hosted by the app, so `xcodebuild test` runs `applicationDidFinishLaunching` for real. The delegate returns early when `XCTestConfigurationFilePath` is set, or every test run would tick the engine and touch `sudo`. Tests use fakes, temp directories and their own `UserDefaults` suites; nothing under `Tests/` may run `sudo`, `pmset` or `osascript`.

Signing: the one `Apple Development` identity on this Mac. The team is the certificate's OU, kept in the untracked `Signing.local.xcconfig`; the string in parentheses beside the name in `security find-identity` is the certificate's own name and xcodebuild rejects it as a team. Hardened runtime on, sandbox off: the app runs `sudo` and `osascript` and reads under `~/.claude`, none of which a sandboxed process can do. Ad-hoc signing would also work for this app, since it keeps nothing in the keychain, but the same identity as Kullanym Notch costs nothing and keeps `make install` builds consistent.

The Release build cannot land in the repository. This one lives under `~/Documents`, which iCloud Drive syncs, and the file provider stamps every bundle inside it with `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P`. `codesign` then refuses the app with `resource fork, Finder information, or similar detritus not allowed`, and a copy made with `ditto --norsrc --noextattr --noqtn` is stamped again before the next command runs. Measured 2026-09-07. Debug builds never hit it because they land in DerivedData under `~/Library`; `scripts/release.sh` writes to `~/Library/Caches/StayUp/build` for the same reason.

xcodegen 2.46.0, `project.yml` is the source and `*.xcodeproj` is ignored. `SWIFT_VERSION: "5.0"` with `SWIFT_STRICT_CONCURRENCY: minimal` keeps Swift 6.3's strict concurrency from arguing with AppKit callbacks; the engine is `@MainActor` and everything else is plain.

The same sync bites the gate. A test that reads a file out of the working tree can block while the file provider materialises it: `ReleaseScriptTests` took 245 s on the first run after `scripts/release.sh` was written and 0.019 s on the next. The tests that read the install script and the guard read them out of the built app bundle in DerivedData instead, which nothing syncs.

Logs: the app has no window, so `/usr/bin/log stream --predicate 'subsystem == "com.meric.stayup"' --level debug`. `/usr/bin/log`, because zsh has a builtin called `log`.

## Verifying with the log

`pmset -g log` goes back about a week (on 2026-09-06 it began at 2026-08-30). Three greps answer three questions.

Did the lid sleep the machine: `pmset -g log | grep "Clamshell Sleep" | tail -3`. A line with a timestamp in the window the lid was closed means it slept.

Has it slept at all since boot: `pmset -g log | grep "Total Sleep/Wakes"`.

Who is holding an idle assertion right now: `pmset -g assertions`, the block under `Listed by owning process`. Not relevant to the lid, but the first place anyone looks, so know what it does and does not show.

And the flag itself: `pmset -g | grep SleepDisabled`.
