#!/bin/bash
#
# Build, Developer ID-sign, notarize, and package MarkDone for distribution.
#
# One-time prerequisites (see RELEASING.md):
#   1. Install a "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → your team → Manage Certificates → +).
#   2. Store notarization credentials once:
#        xcrun notarytool store-credentials MarkDoneNotary \
#          --apple-id "you@example.com" --team-id TEAMID
#      (prompts for an app-specific password from appleid.apple.com)
#
# Usage:
#   TEAM_ID=XXXXXXXXXX ./scripts/package.sh
#   (optional overrides: DEV_ID="Developer ID Application: Your Name (XXXXXXXXXX)"
#                        NOTARY_PROFILE=MarkDoneNotary  SKIP_NOTARIZE=1)
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-MarkDoneNotary}"

# Auto-detect the Developer ID Application identity if not provided.
if [[ -z "${DEV_ID:-}" ]]; then
  DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
fi
if [[ -z "${DEV_ID:-}" ]]; then
  echo "ERROR: No 'Developer ID Application' identity found in the keychain."
  echo "Install a Developer ID cert first (see RELEASING.md)."
  exit 1
fi
# Derive Team ID from the identity string "…(TEAMID)" if not supplied.
TEAM_ID="${TEAM_ID:-$(echo "$DEV_ID" | sed -nE 's/.*\(([A-Z0-9]+)\)$/\1/p')}"
echo "Signing identity: $DEV_ID"
echo "Team ID:          ${TEAM_ID:-<unknown>}"

echo "==> Regenerating project"
python3 scripts/genproj.py >/dev/null

echo "==> Building Release (Developer ID, hardened runtime)"
rm -rf build-release
xcodebuild -project MarkDone.xcodeproj -scheme MarkDone -configuration Release \
  -derivedDataPath build-release \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEV_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -5

APP="build-release/Build/Products/Release/MarkDone.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p dist

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"
# Notarization rejects apps carrying the debug get-task-allow entitlement.
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "get-task-allow"; then
  echo "ERROR: get-task-allow entitlement present — notarization would fail."
  exit 1
fi

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  echo "==> Notarizing (this can take a few minutes)"
  ditto -c -k --keepParent "$APP" "dist/MarkDone-notarize.zip"
  SUBMIT_OUT=$(xcrun notarytool submit "dist/MarkDone-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)
  echo "$SUBMIT_OUT"
  rm -f "dist/MarkDone-notarize.zip"
  if ! grep -q "status: Accepted" <<<"$SUBMIT_OUT"; then
    echo "==> Notarization FAILED — fetching log:"
    SUB_ID=$(grep -m1 -E "^ *id:" <<<"$SUBMIT_OUT" | awk '{print $2}')
    [[ -n "$SUB_ID" ]] && xcrun notarytool log "$SUB_ID" --keychain-profile "$NOTARY_PROFILE"
    exit 1
  fi
  echo "==> Stapling ticket"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

echo "==> Packaging ZIP + DMG (v$VERSION)"
# ZIP: just the (already notarized+stapled) app.
ditto -c -k --keepParent "$APP" "dist/MarkDone-$VERSION.zip"

# DMG: build, then sign → notarize → staple (a DMG is a separate artifact with its
# own hash, so it needs its own notarization — stapling alone gives "Record not found").
DMG="dist/MarkDone-$VERSION.dmg"
rm -rf dist/stage
mkdir -p dist/stage
cp -R "$APP" dist/stage/
ln -s /Applications dist/stage/Applications
hdiutil create -volname "MarkDone" -srcfolder dist/stage -ov -format UDZO "$DMG" >/dev/null
rm -rf dist/stage
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  echo "==> Signing + notarizing DMG"
  codesign --force --sign "$DEV_ID" --timestamp "$DMG"
  DMG_OUT=$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)
  echo "$DMG_OUT" | grep -E "status:" | tail -1
  if grep -q "status: Accepted" <<<"$DMG_OUT"; then
    xcrun stapler staple "$DMG"
  else
    echo "==> DMG notarization FAILED:"; echo "$DMG_OUT" | tail -5; exit 1
  fi
fi

echo ""
echo "Done. Artifacts in dist/:"
ls -lh dist/*.dmg dist/*.zip 2>/dev/null | awk '{print "  "$5, $9}'
echo ""
echo "Verify a clean machine would accept it:"
echo "  spctl -a -vvv -t install \"$APP\""
