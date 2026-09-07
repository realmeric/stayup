#!/bin/sh
#
# The flag's dead man's handle.
#
# Run by a LaunchAgent every 60 s. If the flag is up and the lease is missing
# or in the past, the app is not there to take it down, so this does. That
# covers a crash, a hang and a force-quit; a reboot is the LaunchDaemon's job.
#
# It never calls `sleepnow`. A lease can lapse because the app was busy for a
# minute, and a guard that puts the Mac to sleep on a hunch is the wrong kind
# of safety. It clears the flag; if the lid is closed, powerd takes it from
# there.
#
# launchd gives a job almost no environment, so every path is absolute. The
# tests rewrite the two /usr/bin paths below in a copy of this file, which is
# how they stand fakes in front of pmset and sudo.

set -u

pmset=/usr/bin/pmset
sudo=/usr/bin/sudo
lease="$HOME/Library/Application Support/StayUp/lease"

# The same first-two-tokens rule as SleepFlag.parse: a leading space, the
# word, two tabs, the digit, and no line at all when it was never set.
flag=$("$pmset" -g 2>/dev/null | /usr/bin/awk '$1 == "SleepDisabled" { print $2; exit }')
[ "${flag:-0}" = "1" ] || exit 0

if [ ! -f "$lease" ]; then
    "$sudo" -n "$pmset" -a disablesleep 0
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') stayup guard: flag cleared, lease missing"
    exit 0
fi

stamp=$(/usr/bin/head -n 1 "$lease" | /usr/bin/tr -d '[:space:]')
until_epoch=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%SZ" -u "$stamp" +%s 2>/dev/null || echo 0)
now_epoch=$(/bin/date +%s)

if [ "$until_epoch" -lt "$now_epoch" ]; then
    "$sudo" -n "$pmset" -a disablesleep 0
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') stayup guard: flag cleared, lease expired at $stamp"
fi

exit 0
