#!/bin/sh
#
# The one thing StayUp needs a password for, done once.
#
#   install-helper.sh <user>            install the rule and the boot reset
#   install-helper.sh <user> remove     take both away again
#
# Run as root through osascript's administrator prompt, which means a minimal
# environment and no PATH worth trusting: every path here is absolute. Each
# step prints a line, so osascript's output reads back as a receipt.

set -eu

user=${1:?usage: install-helper.sh <user> [remove]}
what=${2:-install}

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

candidate=$(/usr/bin/mktemp /tmp/stayup-sudoers.XXXXXX)
echo "$user ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0" > "$candidate"
if ! /usr/sbin/visudo -cf "$candidate" > /dev/null 2>&1; then
    /bin/rm -f "$candidate"
    echo "stayup: the rule for '$user' does not parse; nothing was installed" >&2
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
