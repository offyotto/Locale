# Security Policy

Locale writes to `/etc/hosts` through a bundled `SMAppService` privileged helper.
The main app talks to the helper over XPC and the helper only accepts requests
from the Locale app signature.

## Reporting

Please report security issues privately to the repository owner instead of opening a public issue.

## Scope

Security-sensitive areas include:

- `/etc/hosts` parsing and writing
- privileged helper registration and XPC validation
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
