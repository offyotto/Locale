# Security Policy

Locale applies host mappings through a sandboxed DNS Proxy Network Extension.
The main app and extension communicate through the App Group
`group.dev.offyotto.Locale`.

Locale does not edit `/etc/hosts`, install a privileged helper, or run commands
with elevated privileges.

## Reporting

Please report security issues privately to the repository owner instead of opening a public issue.

## Scope

Security-sensitive areas include:

- DNS query parsing and response generation
- DNS fallback forwarding for unmatched hostnames
- App Group configuration storage
- Network Extension activation and settings
- hostname and IP validation
- signed release packaging

## Expected Behavior

When a context is active, Locale should answer only hostnames that match enabled
entries in that context. Everything else should forward to the system resolver.
