# Releasing Locale

Locale ships a sandboxed macOS app with a bundled DNS Proxy Network Extension.
Distribution builds must be signed with profiles that include:

- App Groups: `group.dev.offyotto.Locale`
- System Extension install
- Network Extension: DNS Proxy

## Prerequisites

- A `Developer ID Application` certificate in Keychain Access for direct distribution, or Mac App Store signing assets for App Store builds.
- A saved notary profile named `LocaleNotary` for direct distribution.
- Network Extension and System Extension capabilities enabled for the app identifiers in the Apple Developer portal.

## App Store Archives In Xcode

Open `Locale.xcodeproj`, select the `LocaleApp` scheme, and archive that
scheme. The app and `LocaleDNSProxy` targets use automatic signing with the
development team `6VDP675K4L`.

For TestFlight or App Store submission, choose **App Store Connect** in
Organizer. Do not choose Direct Distribution for this path. Apple's Store
profiles carry the Network Extension value `dns-proxy`, which is what the
`Release` configuration uses.

If you intentionally need a Direct Distribution archive, switch the scheme to
`LocaleAppDirect` before archiving. Direct profiles carry
`dns-proxy-systemextension`, so that scheme archives the separate `Direct`
configuration with `Resources/LocaleDirect.entitlements` and
`Resources/LocaleDNSProxyDirect.entitlements`. The Direct configuration archives
unsigned on purpose; Xcode signs it during export with the Direct/Developer ID
profiles.

The repeatable CLI path for Developer ID export is:

```bash
./script/export_developer_id.sh
```

It writes:

```text
dist/developer-id/Locale.app
```

Do not archive the Swift package workspace directly. Xcode treats package
archives as Generic Xcode Archives because there is no installable app target
owning the archive.

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

The notarization script signs with the Direct entitlement files because
Developer ID and Direct system extension profiles use the `-systemextension`
Network Extension values.

## Network Extension Notes

`LocaleDNSProxy` is staged as a system extension at:

```text
Contents/Library/SystemExtensions/dev.offyotto.Locale.LocaleDNSProxy.systemextension
```

The extension starts with `NEProvider.startSystemExtensionMode()` and exposes a
`NEDNSProxyProvider` class. The main app activates it with
`OSSystemExtensionManager`, then configures `NEDNSProxyManager` to point at the
extension bundle identifier.

First launch may require the user to approve the system extension and DNS proxy
configuration in System Settings. Context switching after approval does not use
root privileges or edit system host files.
