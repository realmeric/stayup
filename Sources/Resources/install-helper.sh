#!/bin/sh
#
# The one thing StayUp needs a password for, done once.
#
#   install-helper.sh <uid>            install the rule and the boot reset
#   install-helper.sh <uid> remove     take both away again
#
# Run as root through osascript's administrator prompt, which means a minimal
# environment and no PATH worth trusting: every path here is absolute. Each
# step prints a line, so osascript's output reads back as a receipt.

set -eu

uid=${1:?usage: install-helper.sh <uid> [remove]}
what=${2:-install}

# Digits or nothing. `#501` is sudoers' user-ID spec, but `#` followed by
# anything else is a comment, and visudo accepts a comment happily: a rule
# built from a bad argument would install, parse, grant nothing, and leave the
# app saying it was set up.
case "$uid" in
    '' | *[!0-9]*)
        echo "stayup: '$uid' is not a uid; nothing was installed" >&2
        exit 1
        ;;
esac

rule=/etc/sudoers.d/stayup
daemon=/Library/LaunchDaemons/com.meric.stayup.reset.plist
here=$(/usr/bin/dirname "$0")

if [ "$what" = "remove" ]; then
    /bin/launchctl bootout system/com.meric.stayup.reset 2>/dev/null || true
    echo "stayup: boot reset unloaded"
    /bin/rm -f "$daemon"
    echo "stayup: $daemon removed"
    /bin/rm -f "$rule"
    echo "stayup: $rule removed"
    /usr/bin/pmset -a disablesleep 0
    echo "stayup: flag down"
    exit 0
fi

# --- the rule -------------------------------------------------------------
#
# Written to a temp file and checked before it goes anywhere near
# /etc/sudoers.d: a syntax error in that directory can lock every sudo on the
# machine, and this is the one moment it can still be caught.

# The user is named by uid. `#501` is sudoers' own user spec, and digits read
# the same to sudoers and to the shell; a short name is free-form text that
# would have to be sanitized against both.
candidate=$(/usr/bin/mktemp /tmp/stayup-sudoers.XXXXXX)
echo "#$uid ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0" > "$candidate"
if ! /usr/sbin/visudo -cf "$candidate" > /dev/null 2>&1; then
    /bin/rm -f "$candidate"
    echo "stayup: the rule for uid $uid does not parse; nothing was installed" >&2
    exit 1
fi
/usr/bin/install -o root -g wheel -m 0440 "$candidate" "$rule"
/bin/rm -f "$candidate"
echo "stayup: $rule installed"

# --- the boot reset -------------------------------------------------------
#
# The flag survives a reboot on its own (it lives in a preferences plist that
# powerd reapplies), so something has to take it down on the way up.

/bin/cp "$here/com.meric.stayup.reset.plist" "$daemon"
/usr/sbin/chown root:wheel "$daemon"
/bin/chmod 644 "$daemon"
/bin/launchctl bootout system/com.meric.stayup.reset 2>/dev/null || true
/bin/launchctl bootstrap system "$daemon"
echo "stayup: boot reset loaded"

# The moment the rule exists is a good moment for the flag to be known down.
/usr/bin/pmset -a disablesleep 0
echo "stayup: flag down"
