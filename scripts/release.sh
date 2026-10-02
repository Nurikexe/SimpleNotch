#!/bin/zsh
# Builds, signs (Developer ID), notarizes and packages SimpleNotch, then
# writes a Sparkle appcast for GitHub Releases.
#
# One-time setup (see README "Releasing"):
#   1. Xcode > Settings > Accounts > Manage Certificates > + "Developer ID Application".
#   2. xcrun notarytool store-credentials SimpleNotch --apple-id <you> --team-id <team-id>
#   3. build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
#      and paste the printed public key into SimpleNotch/Info.plist as SUPublicEDKey.
#
# Usage: scripts/release.sh            (version comes from MARKETING_VERSION)
#        scripts/release.sh --publish  (also creates the GitHub release)
#        scripts/release.sh --no-notarize  (signed but not notarized; macOS warns on first open)
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE=${NOTARY_PROFILE:-SimpleNotch}
PUBLISH=0 NOTARIZE=1
for arg in "$@"; do
  case $arg in
    --publish) PUBLISH=1 ;;
    --no-notarize) NOTARIZE=0 ;;
    *) echo "Unknown option $arg"; exit 1 ;;
  esac
done
OUT=build/release
SPARKLE=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin

/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" SimpleNotch/Info.plist >/dev/null 2>&1 \
  || { echo "SUPublicEDKey missing from Info.plist (run generate_keys first)"; exit 1; }
IDENTITY=$(security find-identity -v -p codesigning | grep -m1 "Developer ID Application" || true)
[[ -n "$IDENTITY" ]] || { echo "No Developer ID Application certificate in the keychain"; exit 1; }
# The team comes from the certificate, e.g. "Developer ID Application: Name (TEAMID)".
TEAM=${TEAM_ID:-$(echo "$IDENTITY" | sed -E 's/.*\(([A-Z0-9]{10})\)".*/\1/')}

rm -rf "$OUT" && mkdir -p "$OUT"

echo "› Archiving"
xcodebuild -project SimpleNotch.xcodeproj -scheme SimpleNotch -configuration Release \
  -derivedDataPath build/DerivedData -scmProvider system \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" \
  -archivePath "$OUT/SimpleNotch.xcarchive" archive > "$OUT/archive.log" 2>&1 || { tail -30 "$OUT/archive.log"; exit 1; }
[[ -d "$OUT/SimpleNotch.xcarchive" ]] || { echo "Archive failed"; exit 1; }

echo "› Exporting with Developer ID"
cat > "$OUT/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -allowProvisioningUpdates -archivePath "$OUT/SimpleNotch.xcarchive" \
  -exportOptionsPlist "$OUT/export.plist" -exportPath "$OUT"
APP="$OUT/SimpleNotch.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

# Notarization rejects any executable without the hardened runtime, and the
# export re-signs the media helper without it. Re-sign it, then reseal the app.
SIGNER=$(echo "$IDENTITY" | awk '{print $2}')
HELPER="$APP/Contents/Resources/MediaRemoteAdapterTestClient"
codesign -f -s "$SIGNER" -o runtime --timestamp "$HELPER"
codesign -f -s "$SIGNER" -o runtime --timestamp \
  --preserve-metadata=entitlements,requirements,flags "$APP"
codesign --verify --deep --strict "$APP"

echo "› Notarizing $VERSION"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
if (( NOTARIZE )); then
  xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose "$APP"
else
  echo "  skipped (--no-notarize)"
fi

echo "› Packaging"
mkdir -p "$OUT/updates"
# A fixed name keeps the README's releases/latest/download/SimpleNotch.dmg link working.
DMG="$OUT/updates/SimpleNotch.dmg"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/SimpleNotch.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname SimpleNotch -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --sign "$SIGNER" --timestamp "$DMG"
if (( NOTARIZE )); then
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "› Writing appcast"
"$SPARKLE/generate_appcast" \
  --download-url-prefix "https://github.com/Nurikexe/SimpleNotch/releases/download/v$VERSION/" \
  "$OUT/updates"

if (( PUBLISH )); then
  echo "› Publishing v$VERSION"
  NOTES=()
  (( NOTARIZE )) || NOTES=(--notes "**First launch:** this build isn't notarized, so macOS blocks the first open. Open **System Settings › Privacy & Security** and click **Open Anyway** next to SimpleNotch, or run \`xattr -dr com.apple.quarantine /Applications/SimpleNotch.app\`.")
  gh release create "v$VERSION" "$DMG" "$OUT/updates/appcast.xml" \
    --title "SimpleNotch $VERSION" --generate-notes "${NOTES[@]}"
  exit 0
fi

echo
echo "Done. Create GitHub release v$VERSION and upload:"
echo "  $DMG"
echo "  $OUT/updates/appcast.xml"
echo "e.g. gh release create v$VERSION \"$DMG\" \"$OUT/updates/appcast.xml\" --title \"SimpleNotch $VERSION\""
