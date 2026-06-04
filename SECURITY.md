# Security Policy

Locale writes to `/etc/hosts` only after macOS administrator authorization.

## Reporting

Please report security issues privately to the repository owner instead of opening a public issue.

## Scope

Security-sensitive areas include:

- `/etc/hosts` parsing and writing
- privileged AppleScript command construction
- backup creation and restore behavior
- hostname and IP validation
- notarized release packaging

## Expected Behavior

Locale should only replace content between:

```text
# BEGIN LOCALE MANAGED HOSTS
# END LOCALE MANAGED HOSTS
```

Everything outside that block must be preserved.

