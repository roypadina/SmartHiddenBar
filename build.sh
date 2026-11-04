#!/bin/sh
# Builds build/SmartHiddenBar.app, signed with a stable local identity (ad-hoc fallback), installs to /Applications.
# RELEASE=1 ./build.sh -> identity-signed build + build/SmartHiddenBar.zip, no install. CI=1 -> ad-hoc compile check, no install.
SET=fold-chevron  # icon set in Assets/icons/: fold-chevron | peek-strip | curtain-panel
set -e
cd "$(dirname "$0")"
APP=build/SmartHiddenBar.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Sparkle (in-app updates): the official release tarball, pinned by SHA-256, cached in build/.
SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
SPARKLE=build/sparkle-$SPARKLE_VERSION
if [ ! -d "$SPARKLE/Sparkle.framework" ]; then
  mkdir -p "$SPARKLE"
  curl -sfL -o "$SPARKLE.tar.xz" "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
  echo "$SPARKLE_SHA256  $SPARKLE.tar.xz" | shasum -a 256 -c - >/dev/null
  tar -xJf "$SPARKLE.tar.xz" -C "$SPARKLE" ./Sparkle.framework ./bin
  rm -f "$SPARKLE.tar.xz"
fi
swiftc -O -target arm64-apple-macos27.0 -F "$SPARKLE" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  *.swift -o "$APP/Contents/MacOS/SmartHiddenBar"
cp Info.plist "$APP/Contents/"
I=Assets/icons/$SET
cp "$I"/menubar-hidden.png "$I"/menubar-hidden@2x.png "$I"/menubar-shown.png "$I"/menubar-shown@2x.png "$I"/AppIcon.icns "$APP/Contents/Resources/"
rm -rf "$APP/Contents/Frameworks" && mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"  # ditto keeps its symlinks
# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc (-) gets a new hash each build.
ID="${SHB_SIGN_IDENTITY:-KeyLayoutSwitcher Dev}"
security find-identity -v -p codesigning | grep -q "\"$ID\"" || { ID=-; echo "signing identity missing: ad-hoc build"; }
[ -n "$CI" ] && ID=-  # CI: ad-hoc compile check
# Inside-out: Sparkle's helpers and framework, then the app.
find "$APP/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' -o -name '*.dylib' \
  -o \( -name Autoupdate -type f \) \) | while read -r f; do
  codesign -f --preserve-metadata=identifier,entitlements,flags -s "$ID" "$f"
done
codesign -f -s "$ID" "$APP"
codesign --verify --deep --strict "$APP"
# A build/ copy LaunchServices knows about can win the bundle-id lookup over /Applications: keep it unregistered.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
# RELEASE=1: zip for GitHub Releases / the cask. CI: compile check only. Neither installs.
if [ -n "$RELEASE" ]; then
  rm -f build/SmartHiddenBar.zip && ditto -c -k --keepParent "$APP" build/SmartHiddenBar.zip && echo "built build/SmartHiddenBar.zip" && shasum -a 256 build/SmartHiddenBar.zip
  # Sparkle feed for this release only (uploaded next to the zip). Only with the key whose public half the app
  # ships (SUPublicEDKey); any other key makes a feed every copy refuses.
  if [ "$("$SPARKLE/bin/generate_keys" -p 2>/dev/null || true)" = "$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' Info.plist)" ]; then
    VER=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
    D=$(mktemp -d)
    cp build/SmartHiddenBar.zip "$D/"
    # This version's CHANGELOG section becomes the update prompt's release notes.
    awk -v v="## [$VER]" 'index($0, v) == 1 {f=1; next} /^## \[/ {f=0} f' CHANGELOG.md > "$D/SmartHiddenBar.md"
    rm -f build/appcast.xml  # generate_appcast merges into an existing file
    "$SPARKLE/bin/generate_appcast" --embed-release-notes \
      --download-url-prefix "https://github.com/roypadina/SmartHiddenBar/releases/download/v$VER/" -o build/appcast.xml "$D"
    rm -rf "$D"
    echo "built build/appcast.xml"
  else
    echo "Sparkle signing key (matching SUPublicEDKey) not in the keychain: no appcast.xml"
  fi
  exit 0
fi
[ -n "$CI" ] && exit 0
# MenuBarAgent's allow-list resolves bundle ids via LaunchServices, which prefers the /Applications copy: run that one.
if pgrep -qx SmartHiddenBar; then echo "/Applications copy running, not replaced: quit it and rerun"
else rm -rf /Applications/SmartHiddenBar.app && ditto "$APP" /Applications/SmartHiddenBar.app && echo "installed /Applications/SmartHiddenBar.app"; fi
