# Releasing Locale

Locale is distributed outside the Mac App Store because it needs administrator
authorization to update `/etc/hosts`.

## Prerequisites

- A `Developer ID Application` certificate in Keychain Access.
- A saved notary profile named `LocaleNotary`.

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
