# Contributing

Thanks for helping improve Locale.

## Development

Build the app with:

```bash
swift build -c release
```

Build a runnable app bundle with:

```bash
./script/build_and_run.sh --build-only
```

Run the app locally with:

```bash
./script/build_and_run.sh --verify
```

## Pull Requests

- Keep changes focused.
- Do not commit generated app bundles, notarized ZIPs, SwiftPM build output, or local screenshots.
- Update `README.md` when behavior changes.
- Run `swift build -c release` before opening a pull request.

## Safety

Locale applies DNS mappings through a sandboxed DNS Proxy Network Extension. Changes to `SystemApplyService`, `DNSProxyController`, or `DNSProxyProvider` should be reviewed carefully. The app must not introduce direct `/etc/hosts` edits, privileged helpers, or `osascript` calls.
