#!/bin/bash
#
# Builds a signed, notarized DMG for the native macOS Colorpicker app
# and (optionally) uploads it to the GitHub release.
#
#   ./package.sh                 # build + sign + DMG + notarize + staple
#   ./package.sh --skip-notarize # build + sign + DMG only (no Apple notarization)
#   ./package.sh --upload        # also upload the DMG to the GitHub release
#
# Env overrides:
#   CODESIGN_IDENTITY  (default: Developer ID Application: Abrar Zharifan Syah (JSYLVAZ935))
#   DEVELOPMENT_TEAM   (default: JSYLVAZ935)
#   NOTARY_PROFILE     (default: colorpicker-notary; a notarytool keychain profile)
#   VERSION            (default: from Colorpicker/Info.plist CFBundleShortVersionString)
#
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Abrar Zharifan Syah (JSYLVAZ935)}"
TEAM="${DEVELOPMENT_TEAM:-JSYLVAZ935}"
PROFILE="${NOTARY_PROFILE:-colorpicker-notary}"
APP_NAME="Colorpicker"

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Colorpicker/Info.plist)}"
DMG_NAME="Colorpicker-${VERSION}.dmg"
DMG_PATH="build/${DMG_NAME}"

SKIP_NOTARIZE=false
UPLOAD=false
for arg in "$@"; do
  case "$arg" in
    --skip-notarize) SKIP_NOTARIZE=true ;;
    --upload) UPLOAD=true ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

echo "==> Building ${APP_NAME} ${VERSION} (signed: ${IDENTITY})"
xcodegen generate >/dev/null
xcodebuild \
  -project Colorpicker.xcodeproj \
  -scheme Colorpicker \
  -configuration Release \
  -derivedDataPath build \
  -quiet \
  build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_ENTITLEMENTS="$PWD/Colorpicker/Colorpicker.entitlements" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

APP="build/Build/Products/Release/${APP_NAME}.app"
echo "==> Verifying app signature"
codesign --verify --deep --strict "$APP"
{ codesign -dv --verbose=2 "$APP" 2>&1 || true; } | head -6 || true
# Pre-notarization Gatekeeper check: a fresh build reports
# "Unnotarized Developer ID" until Apple notarizes this exact hash.
# Fail only if the signature itself is invalid.
SPCTL_OUT="$(spctl -a -t exec -vv "$APP" 2>&1 || true)"
echo "$SPCTL_OUT"
if ! echo "$SPCTL_OUT" | grep -qE "source=(Notarized Developer ID|Developer ID Application|Unnotarized Developer ID)"; then
  echo "ERROR: unexpected Gatekeeper status" >&2
  exit 1
fi

echo "==> Creating DMG ${DMG_PATH}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "==> Signing DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose "$DMG_PATH"

if [ "$SKIP_NOTARIZE" = true ]; then
  echo "==> Skipping notarization (--skip-notarize)"
else
  echo "==> Submitting to Apple notarization (profile: ${PROFILE})"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
  echo "==> Stapling ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  echo "==> Gatekeeper check"
  spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
ls -la "$DMG_PATH"

if [ "$UPLOAD" = true ]; then
  TAG="v${VERSION}"
  echo "==> Uploading to GitHub release ${TAG}"
  gh release upload "$TAG" "$DMG_PATH" --clobber
fi
