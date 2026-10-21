#!/usr/bin/env bash
# Archive Sunnyside and upload it to App Store Connect (TestFlight).
#
# Auth, one of:
#   A) An Apple ID for team 898NP95GBU signed into Xcode (Settings → Accounts). Nothing else needed.
#   B) An App Store Connect API key (no Apple ID in Xcode needed):
#        export ASC_KEY_ID=ABC123DEFG ASC_ISSUER_ID=xxxxxxxx-xxxx-...   # from appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API
#        key file at ~/.private_keys/AuthKey_$ASC_KEY_ID.p8 (or set ASC_KEY_PATH)
#
# Before the first upload the app record must exist in App Store Connect
# (My Apps → + → iOS, bundle ID com.didisd.SunnySideApp, name Sunnyside).
set -euo pipefail
cd "$(dirname "$0")/.."

AUTH=()
if [ -n "${ASC_KEY_ID:-}" ]; then
  KEY_PATH="${ASC_KEY_PATH:-$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8}"
  [ -f "$KEY_PATH" ] || { echo "API key file not found: $KEY_PATH" >&2; exit 1; }
  [ -n "${ASC_ISSUER_ID:-}" ] || { echo "ASC_ISSUER_ID is not set" >&2; exit 1; }
  AUTH=(-authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

BUILD_NUMBER=$(date +%Y%m%d%H%M)   # must increase on every upload
ARCHIVE=build/Sunnyside.xcarchive
rm -rf "$ARCHIVE" build/export

echo "▶ Archiving (build $BUILD_NUMBER)"
xcodebuild archive -project Sunnyside.xcodeproj -scheme Sunnyside -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -allowProvisioningUpdates "${AUTH[@]}" \
  2>&1 | grep -E "error:|warning: .*(sign|provision)|ARCHIVE (SUCCEEDED|FAILED)" || true
[ -d "$ARCHIVE" ] || { echo "Archive failed; see errors above." >&2; exit 1; }

echo "▶ Exporting and uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates "${AUTH[@]}" \
  2>&1 | grep -iE "error|Upload succeeded|EXPORT (SUCCEEDED|FAILED)" || true
grep -q "Upload succeeded" build/export/DistributionSummary.plist 2>/dev/null || ls build/export >/dev/null

echo "Uploaded. In App Store Connect → TestFlight the build appears after processing (5–20 min)."
echo "Add yourself as an internal tester once, then install from the TestFlight app on the phone."
