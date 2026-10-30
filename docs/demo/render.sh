#!/bin/bash
# Regenerates the SmartHiddenBar demo from scratch: compile kit + scene, render frames offscreen (no window is ever shown,
# nothing is clicked or captured, the installed app is never launched), encode. One command: ./render.sh
# The scene reads the app's real menu bar glyphs (Assets/icons/fold-chevron/menubar-*.png); everything else is the kit + fake data.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="${KIT:-$HERE}"; [ -f "$KIT/DemoKit.swift" ] || KIT="$HERE/../kit"          # repo: kit is vendored next to this file
APP="${APP_SRC:-$HERE/../..}"                                                   # repo: docs/demo -> repo root
GIF="${GIF:-$HERE/../demo.gif}"                                                 # repo: docs/demo.gif
BUILD="${BUILD:-${TMPDIR:-/tmp}/smarthiddenbar-demo}"                           # never inside the repo (hundreds of MB of frames)
mkdir -p "$BUILD"
swiftc -swift-version 5 -parse-as-library -O -o "$BUILD/demo" "$KIT/DemoKit.swift" "$HERE/scene.swift"
rm -rf "$BUILD/frames"
SHB_ASSETS="$APP/Assets/icons/fold-chevron" \
  "$BUILD/demo" "$BUILD/frames" 30 -AppleLocale en_US -AppleLanguages "(en)"
POSTER=${POSTER:-246}  # icon bar open (reviewer-approved poster frame)
"$KIT/encode.sh" "$BUILD/frames" "$GIF" "${MP4:-}" "${WEBP:-}" "${POSTER:-}"
rm -rf "$BUILD/frames"                                                            # only after a successful encode (set -e)
