#!/usr/bin/env bash
# Build Sunnyside for a connected iPhone, install it and launch it.
# Needs: the phone plugged in (or on the same Wi-Fi and paired), unlocked,
# and an Apple ID for team 898NP95GBU signed into Xcode (Settings → Accounts).
#
#   scripts/device-run.sh            # first available iPhone
#   scripts/device-run.sh "Diddy’s"  # by name or identifier
set -euo pipefail
cd "$(dirname "$0")/.."

PICK="${1:-}"
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk -v pick="$PICK" '
  /iPhone/ && /available/ { if (pick == "" || index($0, pick)) { for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{36}$/) { print $i; exit } } }')
if [ -z "$DEVICE" ]; then
  echo "No available iPhone. Plug it in, unlock it, tap Trust, then try again." >&2
  xcrun devicectl list devices >&2 || true
  exit 1
fi
echo "▶ Building for device $DEVICE"
xcodebuild build -project Sunnyside.xcodeproj -scheme Sunnyside -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath build/dd -allowProvisioningUpdates -quiet
APP=build/dd/Build/Products/Debug-iphoneos/Sunnyside.app
echo "▶ Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "▶ Launching"
xcrun devicectl device process launch --device "$DEVICE" com.sunnyside.app
echo "Done. First time only: on the phone go to Settings → General → VPN & Device Management and trust the developer."
