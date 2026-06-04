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

## Website

The marketing site lives in `website/` and is deployed with GitHub Pages from
`.github/workflows/pages.yml`.

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
