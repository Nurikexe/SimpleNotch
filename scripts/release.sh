#!/bin/zsh
# Builds, signs (Developer ID), notarizes and packages SimpleNotch, then
# writes a Sparkle appcast for GitHub Releases.
#
# One-time setup (see README "Releasing"):
#   1. Xcode > Settings > Accounts > Manage Certificates > + "Developer ID Application".
#   2. xcrun notarytool store-credentials SimpleNotch --apple-id <you> --team-id HMBA454DQ4
#   3. build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
#      and paste the printed public key into boringNotch/Info.plist as SUPublicEDKey.
#
# Usage: scripts/release.sh            (version comes from MARKETING_VERSION)
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE=${NOTARY_PROFILE:-SimpleNotch}
OUT=build/release
SPARKLE=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin

/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" boringNotch/Info.plist >/dev/null 2>&1 \
  || { echo "SUPublicEDKey missing from Info.plist (run generate_keys first)"; exit 1; }
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || { echo "No Developer ID Application certificate in the keychain"; exit 1; }

rm -rf "$OUT" && mkdir -p "$OUT"

echo "› Archiving"
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release \
  -derivedDataPath build/DerivedData -scmProvider system \
  -archivePath "$OUT/SimpleNotch.xcarchive" archive > "$OUT/archive.log" 2>&1 || { tail -30 "$OUT/archive.log"; exit 1; }
[[ -d "$OUT/SimpleNotch.xcarchive" ]] || { echo "Archive failed"; exit 1; }

echo "› Exporting with Developer ID"
cat > "$OUT/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>HMBA454DQ4</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT/SimpleNotch.xcarchive" \
  -exportOptionsPlist "$OUT/export.plist" -exportPath "$OUT"
APP="$OUT/SimpleNotch.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

echo "› Notarizing $VERSION"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"

echo "› Packaging"
mkdir -p "$OUT/updates"
DMG="$OUT/updates/SimpleNotch-$VERSION.dmg"
hdiutil create -volname SimpleNotch -srcfolder "$APP" -ov -format UDZO "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "› Writing appcast"
"$SPARKLE/generate_appcast" \
  --download-url-prefix "https://github.com/Nurikexe/SimpleNotch/releases/download/v$VERSION/" \
  "$OUT/updates"

echo
echo "Done. Create GitHub release v$VERSION and upload:"
echo "  $DMG"
echo "  $OUT/updates/appcast.xml"
echo "e.g. gh release create v$VERSION \"$DMG\" \"$OUT/updates/appcast.xml\" --title \"SimpleNotch $VERSION\""
