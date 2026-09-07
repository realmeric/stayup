#!/bin/zsh
#
# Build the app for real, check it is what it claims to be, and optionally put
# it in /Applications.
#
#   scripts/release.sh           build and verify
#   scripts/release.sh install   and replace /Applications/StayUp.app
#   scripts/release.sh zip       and leave a zip beside it to carry elsewhere
#
# Nothing is written to /Applications unless every check below passes. An app
# that does not verify is one that will fail at launch rather than here, where
# the failure can still be read.
#
# The build does not land in the repository. This one lives under
# ~/Documents, which iCloud Drive syncs, and a file provider stamps every
# bundle it sees with com.apple.FinderInfo; codesign then refuses it with
# "resource fork, Finder information, or similar detritus not allowed". A
# copy made with `ditto --noextattr` is stamped again within the second. So
# the output goes to ~/Library/Caches, which nothing syncs.

set -eu

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
root=${0:a:h:h}
cd "$root"

app_name="StayUp"
bundle_id="com.meric.stayup"
out="$HOME/Library/Caches/StayUp/build"
app="$out/$app_name.app"
what=${1:-}

say() { print -P "%F{cyan}==%f $*" }
bad() { print -P "%F{red}xx%f $*" >&2; exit 1 }

say "generating the project"
xcodegen generate >/dev/null

say "building Release"
rm -rf "$out"
mkdir -p "$out"
xcodebuild -project StayUp.xcodeproj \
           -scheme StayUp \
           -configuration Release \
           -destination 'platform=macOS,arch=arm64' \
           CONFIGURATION_BUILD_DIR="$out" \
           build >/dev/null || bad "the build failed; run it without >/dev/null to see why"

[[ -d "$app" ]] || bad "no $app_name.app came out of the build"

# --- what it says it is ---------------------------------------------------

plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
built=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
[[ "$built" == "$bundle_id" ]] || bad "bundle id is $built, expected $bundle_id"
# Without this the app takes a Dock tile and an app switcher slot, which for a
# menu bar app is the difference between shipped and half-shipped.
[[ $(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$plist") == "true" ]] \
    || bad "LSUIElement is not set; this would appear on the Dock"
say "$app_name $version ($built)"

# --- what it contains -----------------------------------------------------
#
# No icon checks: v1 has no icon of its own on purpose. The two resources
# below are the ones without which the app cannot set itself up at all.

for piece in "Contents/MacOS/$app_name" \
             "Contents/Resources/install-helper.sh" \
             "Contents/Resources/guard.sh" \
             "Contents/Resources/com.meric.stayup.reset.plist"; do
    [[ -e "$app/$piece" ]] || bad "missing $piece"
done

# --- whether it is signed, and how ----------------------------------------

codesign --verify --deep --strict "$app" 2>/dev/null \
    || bad "the signature does not verify"
runtime=$(codesign -d --verbose=2 "$app" 2>&1 | grep -o 'flags=.*' || true)
[[ "$runtime" == *runtime* ]] || bad "the hardened runtime is off: $runtime"
authority=$(codesign -dv --verbose=4 "$app" 2>&1 | grep '^Authority=' | head -1 | cut -d= -f2)
say "signed by $authority, hardened runtime on"

# Gatekeeper's opinion, which is not the same question. A development
# certificate is enough to run here and not enough to hand to a stranger.
if spctl --assess --type execute "$app" >/dev/null 2>&1; then
    say "Gatekeeper accepts it"
else
    say "Gatekeeper will not accept it on another Mac without a right-click Open."
    say "That needs a Developer ID and a notarisation, neither of which exists here."
fi

say "built $app"

# --- putting it somewhere -------------------------------------------------

if [[ "$what" == "install" ]]; then
    destination="/Applications/$app_name.app"
    say "replacing $destination"
    # Quitting rather than killing: the app releases the flag and clears the
    # lease on its way out, and a -9 would leave both for the guard.
    osascript -e 'tell application "StayUp" to quit' 2>/dev/null || true
    pkill -x "$app_name" 2>/dev/null || true
    sleep 1
    rm -rf "$destination"
    ditto "$app" "$destination"
    # Launch Services is told rather than left to notice, or the old copy's
    # registration lingers and the login item points at a path that is gone.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$destination" >/dev/null 2>&1 || true
    open "$destination"
    say "installed and running from /Applications"
fi

if [[ "$what" == "zip" ]]; then
    archive="$out/$app_name $version.zip"
    rm -f "$archive"
    # ditto rather than zip: it keeps the bundle's symlinks and resource forks,
    # which a plain zip flattens and a signature notices.
    ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
    say "wrote $archive"
fi
