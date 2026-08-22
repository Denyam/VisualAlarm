#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

BIN=/tmp/va_brightness_spike
APP=/tmp/VASpike.app

echo "== build =="
swiftc -O brightness_spike.swift -import-objc-header spike.h -o "$BIN"

echo "== unsandboxed baseline =="
codesign --force --sign - "$BIN"
"$BIN" || true

echo "== sandboxed (App Sandbox entitlement, wrapped in .app bundle) =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/VASpike"
cp spike-app-Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --entitlements sandbox.entitlements "$APP"
"$APP/Contents/MacOS/VASpike"
