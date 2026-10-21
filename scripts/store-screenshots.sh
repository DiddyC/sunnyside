#!/usr/bin/env bash
# Capture, frame and (optionally) upload App Store screenshots.
#   scripts/store-screenshots.sh            # capture + frame into build/store/{iphone,ipad}
#   scripts/store-screenshots.sh --upload   # …then replace the 2.0.0 listing's screenshots (resubmits if waiting for review)
# Needs: a simulator build (xcodebuild build -destination "generic/platform=iOS Simulator" -derivedDataPath build/dd),
# an iPhone 17 Pro Max and an iPad Pro 13-inch simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/dd/Build/Products/Debug-iphonesimulator/Sunnyside.app
[ -d "$APP" ] || { echo "Build for the simulator first: xcodebuild build -project Sunnyside.xcodeproj -scheme Sunnyside -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO" >&2; exit 1; }
BUNDLE=com.didisd.SunnySideApp
OUT=build/store; rm -rf "$OUT"; mkdir -p "$OUT/raw_iphone" "$OUT/raw_ipad" "$OUT/iphone" "$OUT/ipad"
swiftc -O scripts/frame-screenshot.swift -o "$OUT/frame" 2>/dev/null

udid() { xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE "[0-9A-F-]{36}"; }
prep() { xcrun simctl boot "$1" 2>/dev/null || true; xcrun simctl bootstatus "$1" -b >/dev/null 2>&1
         xcrun simctl uninstall "$1" $BUNDLE 2>/dev/null || true; xcrun simctl install "$1" "$APP"
         xcrun simctl privacy "$1" grant location $BUNDLE; xcrun simctl location "$1" set 32.0853,34.7818; }
shot() { local u=$1 out=$2 wait=$3; shift 3
         xcrun simctl terminate "$u" $BUNDLE 2>/dev/null || true; xcrun simctl launch "$u" $BUNDLE "$@" >/dev/null; sleep "$wait"
         xcrun simctl io "$u" screenshot "$out" >/dev/null 2>&1; }

IPHONE=$(udid "iPhone 17 Pro Max"); IPAD=$(udid "iPad Pro 13-inch (M4)")
echo "▶ iPhone $IPHONE"; prep "$IPHONE"
shot "$IPHONE" $OUT/raw_iphone/01.png 5 -prefill -appearance dark
shot "$IPHONE" $OUT/raw_iphone/02.png 4 -demo left -appearance dark
shot "$IPHONE" $OUT/raw_iphone/03.png 4 -demo switch -appearance dark
shot "$IPHONE" $OUT/raw_iphone/04.png 4 -demo car -appearance dark
shot "$IPHONE" $OUT/raw_iphone/05.png 8 -sheet from -appearance dark
shot "$IPHONE" $OUT/raw_iphone/06.png 5 -sheet leaving -appearance dark
shot "$IPHONE" $OUT/raw_iphone/07.png 4 -demo switch -appearance light
echo "▶ iPad $IPAD"; prep "$IPAD"
shot "$IPAD" $OUT/raw_ipad/01.png 6 -prefill -appearance dark
shot "$IPAD" $OUT/raw_ipad/02.png 5 -demo left -appearance dark
shot "$IPAD" $OUT/raw_ipad/03.png 5 -demo switch -appearance dark

F=$OUT/frame
$F $OUT/raw_iphone/01.png $OUT/iphone/01.png 1290 2796 "Which side has the shade?" "Tell it where you're going and when." dark
$F $OUT/raw_iphone/02.png $OUT/iphone/02.png 1290 2796 "One word. Left or right." "Sun on your right for the whole trip? Sit left." dark
$F $OUT/raw_iphone/03.png $OUT/iphone/03.png 1290 2796 "See the sun move around your seat." "Drag the slider through the trip. The compass follows." dark
$F $OUT/raw_iphone/04.png $OUT/iphone/04.png 1290 2796 "Train, bus, car, plane or ferry." "Every vehicle gets its own seat map." dark
$F $OUT/raw_iphone/05.png $OUT/iphone/05.png 1290 2796 "Stations and airports, one tap away." "Recent places too. Searches run on Apple Maps." dark
$F $OUT/raw_iphone/06.png $OUT/iphone/06.png 1290 2796 "Leaving later? Pick a time." "Quick picks or a wheel, in local time." dark
$F $OUT/raw_iphone/07.png $OUT/iphone/07.png 1290 2796 "Light or dark. Your call." "Nothing leaves your phone but the place you search for." light
$F $OUT/raw_ipad/01.png $OUT/ipad/01.png 2064 2752 "Which side has the shade?" "Tell it where you're going and when." dark
$F $OUT/raw_ipad/02.png $OUT/ipad/02.png 2064 2752 "One word. Left or right." "Sun on your right for the whole trip? Sit left." dark
$F $OUT/raw_ipad/03.png $OUT/ipad/03.png 2064 2752 "See the sun move around your seat." "Drag the slider through the trip. The compass follows." dark
echo "Framed screenshots in $OUT/iphone and $OUT/ipad"
if [ "${1:-}" = "--upload" ]; then
  python3 -I scripts/upload-screenshots.py --version "${VERSION:-2.0.0}" --iphone $OUT/iphone --ipad $OUT/ipad --resubmit
fi
