#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Locale"
TEAM_ID="${TEAM_ID:-6VDP675K4L}"
NOTARY_PROFILE="${NOTARY_PROFILE:-LocaleNotary}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/LaunchServices/LocaleHelper"
APP_ENTITLEMENTS="$ROOT_DIR/Resources/Locale.entitlements"
SIGNED_ZIP="$DIST_DIR/$APP_NAME-signed.zip"
NOTARIZED_ZIP="$DIST_DIR/$APP_NAME-notarized.zip"

find_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "$CODESIGN_IDENTITY"
    return
  fi

  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*'"$TEAM_ID"'.*\)"/\1/p' \
    | head -n 1
}

IDENTITY="$(find_identity)"
if [[ -z "$IDENTITY" ]]; then
  cat >&2 <<EOF
No Developer ID Application signing identity was found for team $TEAM_ID.

Install the Developer ID Application certificate in Keychain Access, then rerun.
Current code-signing identities:
EOF
  security find-identity -v -p codesigning >&2
  exit 1
fi

cd "$ROOT_DIR"
"$ROOT_DIR/script/build_and_run.sh" --build-only

codesign --force --options runtime --timestamp --identifier "dev.offyotto.Locale.Helper" --sign "$IDENTITY" "$HELPER_BINARY"
codesign --force --options runtime --timestamp --entitlements "$APP_ENTITLEMENTS" --sign "$IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$SIGNED_ZIP" "$NOTARIZED_ZIP"
(
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --keepParent "$APP_NAME.app" "$(basename "$SIGNED_ZIP")"
)

xcrun notarytool submit "$SIGNED_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --team-id "$TEAM_ID" \
  --wait

xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
spctl -a -vv "$APP_BUNDLE"

(
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --keepParent "$APP_NAME.app" "$(basename "$NOTARIZED_ZIP")"
)

echo "Notarized app: $APP_BUNDLE"
echo "Notarized zip: $NOTARIZED_ZIP"
