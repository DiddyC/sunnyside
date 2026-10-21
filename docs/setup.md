# Setup Guide

## 1. Generate and open the project
```bash
xcodegen generate
open Sunnyside.xcodeproj
```
`Sunnyside/Info.plist` is **generated** from `project.yml` on every `xcodegen generate`. Edit `project.yml`, never Info.plist.

## 2. Signing
`project.yml` sets `CODE_SIGN_STYLE: Automatic` and `DEVELOPMENT_TEAM: 898NP95GBU` (the team of the only
Apple Development certificate on the original build Mac). Sign in to Xcode with that Apple ID once so it can
create a provisioning profile. To ship under another team, change `DEVELOPMENT_TEAM` and re-run `xcodegen generate`.

## 3. Run
Any iPhone simulator on iOS 17+ → ⌘R. Place search uses Apple Maps (MapKit): no API key, works in the simulator.

## Screenshots / demo states
Launch with an argument to open a canned result directly (Edit Scheme → Arguments):
```
-demo left      Paris → Strasbourg, winter morning
-demo right     Strasbourg → Paris
-demo switch    Hamburg → Munich, sun crosses over
-demo mixed     Hamburg → Munich, even split → "EITHER"
-demo night     Berlin → Munich overnight
-demo plane     JFK → LHR red-eye
```
Add `-appearance light|dark|system` to force a look. Simulator one-liner:
```bash
xcrun simctl launch booted com.didisd.SunnySideApp -demo switch -appearance light
```

## Test on your phone

**Cable (fastest).** Sign in to Xcode once (Settings → Accounts → + → Apple ID for team 898NP95GBU), plug the phone in, unlock it, tap Trust, then:
```bash
scripts/device-run.sh
```
The first time, trust the developer on the phone under Settings → General → VPN & Device Management.

**TestFlight (no cable, shareable).** The App Store record already exists ("Sunny-Side", bundle ID `com.didisd.SunnySideApp`, team Solomon Labs LLC), so just run:
```bash
scripts/testflight.sh
```
Works with the Apple ID signed into Xcode, or with an App Store Connect API key via `ASC_KEY_ID` / `ASC_ISSUER_ID` (key file in `~/.private_keys/`). The build shows up in TestFlight after processing; install it from the TestFlight app.

## Submit to the App Store
With the App Store Connect API key in place (see TestFlight section), one command creates the version, attaches the newest processed build, sets the release notes from `docs/release-notes/<version>.md` and submits for review:
```bash
scripts/submit.py --dry-run   # everything except the final submit
scripts/submit.py             # submit 2.0.0
```
Without the key: App Store Connect → Sunny-Side → App Store tab → + next to iOS App → version → pick the build → paste the release notes → Add for Review → Submit.

## Store screenshots
`scripts/store-screenshots.sh [--upload]` captures the app on an iPhone 17 Pro Max and iPad Pro 13" simulator
(using the `-demo`, `-prefill` and `-sheet` launch states), frames each shot with a caption via
`scripts/frame-screenshot.swift`, and with `--upload` replaces the listing's screenshots through the API
(`scripts/upload-screenshots.py`), resubmitting for review if the version was waiting.

## Running tests
```bash
xcodebuild test -project Sunnyside.xcodeproj -scheme Sunnyside \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" CODE_SIGNING_ALLOWED=NO
```

## Fonts
None to install. The UI uses SF Pro (system) with a condensed black weight for the verdict, so Dynamic Type works everywhere.
