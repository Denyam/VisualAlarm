#!/bin/zsh
# Does an AD-HOC signed ("codesign --sign -") sandboxed app get a working
# App Group container on this machine?
#
# This is the load-bearing premise for the project's IPC design. If this
# succeeds, the XPC refactor is unnecessary and the existing architecture can
# stay as-is.
set -uo pipefail
cd "$(dirname "$0")"

BIN=/tmp/va_appgroup_probe
APP=/tmp/VAAppGroupProbe.app
GROUP=group.ETFKU52LQ6.co.denis.VisualAlarm.spike

echo "== build =="
swiftc -O appgroup_probe.swift -o "$BIN" || exit 1

echo "== ad-hoc sign with app-sandbox + application-groups =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/VAAppGroupProbe"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>co.denis.VisualAlarm.spike</string>
  <key>CFBundleExecutable</key><string>VAAppGroupProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST

# Force ad-hoc identity; explicitly no provisioning profile.
codesign --force --sign - --entitlements appgroup.entitlements "$APP" 2>&1

echo
echo "== entitlements actually embedded in the signature =="
codesign -d --entitlements :- "$APP" 2>/dev/null

echo
echo "== run =="
"$APP/Contents/MacOS/VAAppGroupProbe"
rc=$?

echo
echo "== group container on disk =="
ls -la "$HOME/Library/Group Containers/$GROUP" 2>&1 | head -5

exit $rc