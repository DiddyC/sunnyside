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
xcrun simctl launch booted com.sunnyside.app -demo switch -appearance light
```

## Running tests
```bash
xcodebuild test -project Sunnyside.xcodeproj -scheme Sunnyside \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" CODE_SIGNING_ALLOWED=NO
```

## Fonts
None to install. The UI uses SF Pro (system) with a condensed black weight for the verdict, so Dynamic Type works everywhere.
