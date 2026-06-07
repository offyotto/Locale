#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_ID="${TEAM_ID:-6VDP675K4L}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist/archives/LocaleDirect.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/dist/developer-id}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT_DIR/Resources/ExportOptions-DeveloperID.plist}"
APP_BUNDLE="$EXPORT_PATH/Locale.app"
DNS_PROXY_BUNDLE_ID="dev.offyotto.Locale.LocaleDNSProxy"
DNS_PROXY_BUNDLE="$APP_BUNDLE/Contents/Library/SystemExtensions/$DNS_PROXY_BUNDLE_ID.systemextension"
APP_ENTITLEMENTS="$ROOT_DIR/Resources/LocaleDirect.entitlements"
DNS_PROXY_ENTITLEMENTS="$ROOT_DIR/Resources/LocaleDNSProxyDirect.entitlements"
APP_PROFILE_NAME="Mac Team Direct Provisioning Profile: dev.offyotto.Locale"
DNS_PROXY_PROFILE_NAME="Mac Team Direct Provisioning Profile: dev.offyotto.Locale.LocaleDNSProxy"

find_identity() {
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*'"$TEAM_ID"'.*\)"/\1/p' \
    | head -n 1
}

find_profile() {
  local expected_name="$1"
  local profile name tmp

  for profile in "$HOME"/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile; do
    [[ -e "$profile" ]] || continue
    tmp="$(mktemp /tmp/locale-profile.XXXXXX.plist)"
    if security cms -D -i "$profile" >"$tmp" 2>/dev/null; then
      name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$tmp" 2>/dev/null || true)"
      rm -f "$tmp"
      if [[ "$name" == "$expected_name" ]]; then
        echo "$profile"
        return 0
      fi
    else
      rm -f "$tmp"
    fi
  done

  return 1
}

cd "$ROOT_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

IDENTITY="$(find_identity)"
APP_PROFILE="$(find_profile "$APP_PROFILE_NAME" || true)"
DNS_PROXY_PROFILE="$(find_profile "$DNS_PROXY_PROFILE_NAME" || true)"

if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application signing identity found for team $TEAM_ID." >&2
  exit 1
fi

if [[ -z "$APP_PROFILE" || -z "$DNS_PROXY_PROFILE" ]]; then
  echo "Missing Direct provisioning profiles. Open Xcode signing once to regenerate them." >&2
  exit 1
fi

xcodebuild \
  -project Locale.xcodeproj \
  -scheme LocaleAppDirect \
  -configuration Direct \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

cp "$APP_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"
cp "$DNS_PROXY_PROFILE" "$DNS_PROXY_BUNDLE/Contents/embedded.provisionprofile"

codesign \
  --force \
  --options runtime \
  --timestamp \
  --identifier "$DNS_PROXY_BUNDLE_ID" \
  --entitlements "$DNS_PROXY_ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$DNS_PROXY_BUNDLE"

codesign \
  --force \
  --options runtime \
  --timestamp \
  --entitlements "$APP_ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Developer ID export: $APP_BUNDLE"
