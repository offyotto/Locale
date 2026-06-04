# Locale

Locale is a macOS utility for switching between named `/etc/hosts` contexts.

It is built with SwiftUI and Swift Package Manager. Locale stores contexts
locally, writes only its own managed block in `/etc/hosts`, creates backups
before every apply, and flushes the local DNS cache after a successful write.

## Features

- Create named hosts contexts for local development, VPNs, labs, and temporary debugging.
- Add, disable, and remove host entries per context.
- Apply a context through the standard macOS administrator authorization prompt.
- Revert to a clean `Home` context to remove Locale-managed hosts.
- Switch active contexts from the menu bar.
- Import and export contexts as JSON.
- Use an adaptive macOS app icon compiled from `Assets/AppIcon.icon`.

## Safety Model

Locale never rewrites arbitrary parts of `/etc/hosts`. It removes and replaces
only this managed block:

```text
# BEGIN LOCALE MANAGED HOSTS
...
# END LOCALE MANAGED HOSTS
```

Everything outside that block is preserved. Before each apply, Locale saves a
backup under:

```text
~/Library/Application Support/Locale/HostsBackups
```

## Current Scope

Locale currently applies hosts entries only. It does not change macOS network
service DNS settings yet.

Because writing `/etc/hosts` requires privileged system access, Locale is aimed
at Developer ID distribution rather than the Mac App Store sandbox.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 6 toolchain

## Build And Run

```bash
./script/build_and_run.sh --verify
```

The app bundle is written to:

```text
dist/Locale.app
```

## Package And Notarize

Install a `Developer ID Application` certificate, then store notary credentials:

```bash
xcrun notarytool store-credentials LocaleNotary \
  --apple-id "$APPLE_ID" \
  --team-id 6VDP675K4L \
  --password "$APP_SPECIFIC_PASSWORD"
```

Then package:

```bash
TEAM_ID=6VDP675K4L ./script/package_notarized.sh
```

The notarized ZIP is written to:

```text
dist/Locale-notarized.zip
```

## Development Notes

- `Package.swift` is the source of truth for opening the app in Xcode.
- Generated app bundles, ZIPs, icon build products, and SwiftPM build outputs are ignored.
- No telemetry or analytics are included.
