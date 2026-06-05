# Locale

Locale is a native macOS utility for switching named DNS contexts.

It is built with SwiftUI and Swift Package Manager. Locale stores contexts
locally, applies the active host mappings through a sandboxed DNS Proxy Network
Extension, and leaves system host files untouched.

## Features

- Create named DNS contexts for local development, VPNs, labs, and temporary debugging.
- Add, disable, and remove host mappings per context.
- Apply a context through Locale's bundled `NEDNSProxyProvider` system extension.
- Revert to a clean `Home` context to clear Locale-managed DNS mappings.
- Switch active contexts from the menu bar.
- Import and export contexts as JSON.
- Use an adaptive macOS app icon compiled from `Assets/AppIcon.icon`.

## Website

The marketing site lives in `website/` and is deployed with GitHub Pages from
`.github/workflows/pages.yml`.

## Architecture

Locale uses a sandboxed main app plus a bundled DNS Proxy Network Extension:

- Main app writes the active context to the shared App Group defaults.
- `LocaleDNSProxy` reads the same App Group data.
- Matching DNS questions receive the configured IP address.
- Unmatched DNS traffic is forwarded to the system DNS servers.

The app does not use `osascript`, a privileged helper, or direct `/etc/hosts`
writes.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift toolchain with SwiftPM
- Apple Developer capabilities for App Groups, System Extensions, and DNS Proxy Network Extension when signing for distribution

## Build And Run

```bash
./script/build_and_run.sh --verify
```

The app bundle is written to:

```text
dist/Locale.app
```
