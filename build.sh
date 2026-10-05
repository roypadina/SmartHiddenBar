#!/bin/sh
# Builds build/SmartHiddenBar.app, signed with a stable local identity (ad-hoc fallback), installs to /Applications.
# RELEASE=1 ./build.sh -> ad-hoc build + build/SmartHiddenBar.zip, no install. CI=1 -> ad-hoc compile check, no install.
SET=fold-chevron  # icon set in Assets/icons/: fold-chevron | peek-strip | curtain-panel
set -e
cd "$(dirname "$0")"
APP=build/SmartHiddenBar.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos27.0 *.swift -o "$APP/Contents/MacOS/SmartHiddenBar"
cp Info.plist "$APP/Contents/"
I=Assets/icons/$SET
cp "$I"/menubar-hidden.png "$I"/menubar-hidden@2x.png "$I"/menubar-shown.png "$I"/menubar-shown@2x.png "$I"/AppIcon.icns "$APP/Contents/Resources/"
# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc (-) gets a new hash each build.
ID="KeyLayoutSwitcher Dev"
security find-identity -v -p codesigning | grep -q "\"$ID\"" || ID=-
[ -n "$RELEASE$CI" ] && ID=-  # release / CI builds: ad-hoc, no local identity
codesign -f -s "$ID" "$APP"
# A build/ copy LaunchServices knows about can win the bundle-id lookup over /Applications: keep it unregistered.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
# RELEASE=1: zip for GitHub Releases / the cask. CI: compile check only. Neither installs.
if [ -n "$RELEASE" ]; then rm -f build/SmartHiddenBar.zip && ditto -c -k --keepParent "$APP" build/SmartHiddenBar.zip && echo "built build/SmartHiddenBar.zip" && shasum -a 256 build/SmartHiddenBar.zip; exit 0; fi
[ -n "$CI" ] && exit 0
# MenuBarAgent's allow-list resolves bundle ids via LaunchServices, which prefers the /Applications copy: run that one.
if pgrep -qx SmartHiddenBar; then echo "/Applications copy running, not replaced: quit it and rerun"
else rm -rf /Applications/SmartHiddenBar.app && ditto "$APP" /Applications/SmartHiddenBar.app && echo "installed /Applications/SmartHiddenBar.app"; fi
