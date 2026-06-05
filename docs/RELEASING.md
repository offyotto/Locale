# Releasing Locale

Locale uses a sandboxed main app plus a bundled `SMAppService` launch daemon to
update `/etc/hosts`. Launch daemon builds must be signed and notarized before the
helper can register successfully.

## Prerequisites

- A `Developer ID Application` certificate in Keychain Access.
- A saved notary profile named `LocaleNotary`.
- The app bundle should live in `/Applications` when testing helper registration.

Create the notary profile with:

```bash
xcrun notarytool store-credentials LocaleNotary \
  --apple-id "$APPLE_ID" \
  --team-id 6VDP675K4L \
  --password "$APP_SPECIFIC_PASSWORD"
```

## Build, Sign, Notarize, And Staple

```bash
TEAM_ID=6VDP675K4L ./script/package_notarized.sh
```

The script writes:

```text
dist/Locale-notarized.zip
```

It also validates the stapled app with `spctl` and `xcrun stapler validate`.

## Privileged Helper Notes

The main app registers `Contents/Library/LaunchDaemons/dev.offyotto.Locale.Helper.plist`.
That plist points at `Contents/Library/LaunchServices/LocaleHelper` using
`BundleProgram`, so relocating the app after registration requires unregistering
and registering the helper again.

The helper only exposes one XPC method: apply a complete hosts-file payload. It
validates the calling app signature before replacing `/private/etc/hosts`.
