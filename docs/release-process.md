# Release process and lessons (Coolside, iOS)

Last updated 22 Oct 2026 after shipping 2.0.0. Read this before any release.

## Identity
- Store name **Coolside: Shady Seat Finder**, subtitle "Sit on the shady side". Display name **Coolside**. Was Sunny-Side (1.x), briefly Shady Seat (never public).
- Bundle ID `com.didisd.SunnySideApp` (cannot change), App Store app ID 6749254551, team 898NP95GBU (Solomon Labs LLC).
- iPad support must stay: an app that shipped on iPad cannot drop it; all four iPad orientations are declared.

## One release, in order
1. Bump `MARKETING_VERSION` in `project.yml`, run `xcodegen generate` (Info.plist is generated; never hand-edit).
2. Write `docs/release-notes/<version>.md`.
3. `scripts/testflight.sh` archives and uploads. It signs with the Apple ID signed into Xcode. The build number is the timestamp.
4. Wait for processing; `scripts/asc-builds.py` lists builds and states. A freshly uploaded build takes a few minutes to appear in the API at all (`submit.py` now waits for it).
5. Listing text: `scripts/store-metadata.py` (name, subtitle, keywords, description, promo).
6. **Screenshots: upload through the App Store Connect website**, not the API (see below).
7. `scripts/submit.py --dry-run` attaches the newest processed build and release notes; `scripts/submit.py` submits for review.
8. Anything edited after submitting needs the submission cancelled first (`upload-screenshots.py --resubmit` does this; the version shows "Developer Rejected" meanwhile, which is normal), then submit again.

## Screenshots (the part that cost a night)
- Apple's slots as of Oct 2026 (App Store Connect → version page):
  - **iPhone 6.1"/6.3" "Dynamic Island (medium)" is the required slot**: 1206×2622 or 1179×2556.
  - iPhone 6.7"/6.9" "Dynamic Island (large)" is optional: 1290×2796, 1320×2868 or 1260×2736.
  - **iPad 13"** required: 2064×2752 or 2048×2732.
  - PNG or JPEG, no alpha. Up to 10 per slot. New "iPhone Duo" slots become required for iOS 27.1 SDK builds from April 2027.
- The website now stores screenshots in an **Asset Library**. The public API (`appScreenshots` upload operations) started returning `ASSET_FAILED` for every upload on 21 Oct 2026, even for trivial test images, via curl, and on another app of the team, and it does not show iPhone images saved through the website. Apple's status page listed nothing. Submission still succeeds when the website shows the images.
- Therefore: generate with `scripts/store-screenshots.sh` (captures iPhone 17 Pro Max + iPad Pro 13", frames with captions), then drag the folders into the website slots. `scripts/upload-screenshots.py` is kept but is unreliable until Apple's API catches up.
- Ready-made sets live on the Desktop in `Coolside-screenshots/` (`iphone-6.1-REQUIRED`, `iphone-6.9`, `ipad-13`, plus JPEG variants).
- "File dimensions are invalid" on the website means the file went into the wrong slot. The website only persists uploads when you press Save.

## App Store Connect API
- Key: `~/.private_keys/AuthKey_<KEY_ID>.p8`, config `~/.config/sunnyside/asc.env` (`ASC_KEY_ID`, `ASC_ISSUER_ID`). The issuer ID is the same for every key on the team.
- An **App Manager** key is enough for the REST scripts but **cannot do cloud signing** in `xcodebuild` ("Cloud signing permission error"). Sign with the Apple ID in Xcode instead; `TESTFLIGHT_USE_API_KEY=1` only with an Admin key.
- To-one relationships that don't exist yet (price schedule, availability) return HTTP 404, not empty data.
- In-app purchase: `com.didisd.SunnySideApp.lifetime`, "Coolside Lifetime", $1.99, created by `scripts/create-iap.py`; still needs a review screenshot and must be included in a review submission before `Monetization.enabled` is flipped.

## Tooling gotchas
- macOS ships bash 3.2: expand optional arrays as `${ARR[@]+"${ARR[@]}"}` under `set -u`.
- Simulator: `xcrun simctl privacy <udid> grant location <bundle>` must run **before the app's first launch** on that bundle ID, or the permission dialog keeps appearing.
- Launch arguments for screenshots and QA: `-demo left|right|switch|mixed|car|ferry|night|plane|dayplane`, `-appearance light|dark|system`, `-sheet from|to|leaving|duration|settings`, `-prefill`.
- `MKLocalSearchCompleterDelegate`: the callback is `completerDidUpdateResults(_:)` reading `completer.results`. A wrong method name compiles silently (protocol methods are optional) and search just never returns. `PlaceSearchTests` hits Apple Maps live to catch this.

## Git and permissions
- Remote URL carries `DiddyC@`; this repo's `credential.helper` is `!gh auth git-credential`, so pushes use the personal GitHub login without touching the work account.
- The Claude Code auto-mode classifier blocks `gh pr create/merge` and edits to `.claude/settings.local.json` unless approved via `/permissions`.
