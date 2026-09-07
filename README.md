# StayUp

Keeps this MacBook awake with the lid closed while an agent is working, and
lets it sleep the moment there is nothing left to wait for. Nothing on the
Dock, nothing to type.

Left click the coffee cup to keep the Mac awake; it fills and turns orange.
Left click again to let it sleep. Control-Option-Command-B does the same from
any app. Right click for the durations, the mode that watches your agents'
transcripts and stops when they stop, and the settings.

The cup is filled while the flag is up and outlined when it is not, so the
state reads without the colour; a paused session is the awake colour dimmed.
Both colours and the glyph are yours to change in Settings › Appearance, and
the shortcut is recorded by pressing it in Settings › General.

## Why the app you already have does not do this

macOS has two ways into sleep and they do not share a switch. Idle sleep is a
policy: nobody has touched the machine, so it sleeps, and any process can hold
an assertion that stops the counting. Clamshell sleep is the lid sensor, and it
does not consult those assertions at all.

`caffeinate` holds an idle assertion. So does everything built on it, including
KeepingYouAwake, whose binary contains `spawnCaffeinateTaskForTimeInterval:`
and nothing about lids. On 2026-09-06 at 23:07:51 KeepingYouAwake created its
assertion; at 23:08:02 the log read `Entering Sleep state due to 'Clamshell
Sleep'`. The assertion was live the whole eleven seconds and the lid closed
straight through it.

One thing overrides a lid close: `pmset -a disablesleep 1`. It needs root, it
survives a reboot, and nothing in the interface shows it is on. On 2026-09-03
something set it on this Mac and the machine did not sleep once for the next 58
hours. StayUp is that flag, raised for a reason and released for a reason.

The screen keeps a third timer of its own, and the flag does not touch that
one either: the Mac stays up and the display still goes dark after a couple of
minutes on battery, which looks exactly like the app having stopped and is
not. StayUp holds the screen up alongside the flag, as `caffeinate -d` does.
Turn that half off in Settings › Sessions if you would rather it rest; with
the lid closed the screen is dark either way.

## What it changes on your Mac

You are asked for your password once. After that:

- `/etc/sudoers.d/stayup`, one line, letting your uid run exactly two commands
  without a password: `pmset -a disablesleep 1` and `pmset -a disablesleep 0`.
  Nothing else.
- `/Library/LaunchDaemons/com.meric.stayup.reset.plist`, which clears the flag
  at every boot.
- `~/Library/LaunchAgents/com.meric.stayup.guard.plist`, a job that runs every
  60 seconds and clears the flag if it is up and StayUp is not renewing its
  claim on it.
- `~/Library/Application Support/StayUp/lease`, that claim: one line, an expiry
  two minutes ahead, rewritten every 20 seconds while the flag is up and
  deleted when it comes down.

The lease is the whole design. Crash the app, hang it, force-quit it, and the
guard finds a lease in the past within a minute and takes the flag down.
Reboot with it up, and the daemon takes it down before you log in. Quit
normally and the app does it itself.

## Getting rid of it

Settings › Helper › Remove… does all of it. By hand:

```bash
sudo launchctl bootout system/com.meric.stayup.reset
sudo rm -f /Library/LaunchDaemons/com.meric.stayup.reset.plist /etc/sudoers.d/stayup
launchctl bootout gui/$(id -u)/com.meric.stayup.guard
rm -rf ~/Library/LaunchAgents/com.meric.stayup.guard.plist ~/Library/Application\ Support/StayUp
sudo pmset -a disablesleep 0
```

## The modes

Timed, 30 minutes to 8 hours. Until the agents finish, which means no
transcript under `~/.claude/projects` or `~/.codex/sessions` has been written
for three minutes; there is no status field to read, so a working agent is a
file growing. Three minutes rather than three seconds because a long tool call
is silence, not idleness. That mode waits five minutes after you start it, so
you can start it before the agent, and stops itself after eight hours.

Indefinite stops itself after 24 hours. You can set that to 0, and you should
not: an uncapped mode is the flag nobody turned off with a nicer icon.

## The guards

Pause when the Mac reports critical heat, and warn at serious. Resume after two
minutes of nominal or fair. Pause below 15% on battery, resume on the cable or
at 20%. There is a switch for only ever running on the cable; it is off, because
you run agents on battery overnight.

## What it cannot do

A thermal pause releases the flag, and if the lid is closed that means the Mac
sleeps and StayUp sleeps with it. It will not resume until you open the lid.
The notification says so rather than pretending otherwise.

The heat reading is `ProcessInfo.thermalState`, which is macOS's judgement, not
a sensor. On this fanless Air `pmset -g therm` has never recorded a warning at
all, so the thermal guard is proved by tests and by `STAYUP_FAKE_THERMAL`, not
by a hot machine.

While StayUp is off it re-applies `disablesleep 0` every 20 seconds, which is
how it checks the rule still works. If another tool raises the flag, StayUp
will quietly lower it.

## Building

```bash
make test     # generate the project and run the tests
make run      # build and launch from DerivedData
make install  # build Release, check it, and put it in /Applications
```

`make install` is not optional if you want Launch at login: macOS registers a
login item only for an app under `/Applications`. The Release build is written
to `~/Library/Caches/StayUp/build` rather than into the repository, because
this one lives in an iCloud-synced folder and a synced bundle cannot be signed.

When something looks wrong:

```bash
/usr/bin/log stream --predicate 'subsystem == "com.meric.stayup"' --level debug
```

and the guard's own log is at `~/Library/Logs/StayUp/guard.log`.
