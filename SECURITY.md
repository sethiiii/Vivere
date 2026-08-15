# Vivere Security Policy

Vivere is local-first and does not require an account, remote API, hosted database, analytics service, or advertising service. Avoiding those systems is an intentional security boundary, not a missing configuration step.

## Credential policy

- Never commit passwords, private API keys, signing certificates, provisioning profiles, `.env` files, private `.xcconfig` files, or service-account files.
- Apple development-team identifiers, bundle identifiers, App Group identifiers, and public client identifiers are not secrets. They do not grant account access by themselves.
- Vivere currently has no database key. Core Data is stored locally in the app sandbox, while the widget receives a compact snapshot through an Apple App Group.
- If a remote service is introduced later, only a provider-documented publishable key may ship in the app. Any privileged or service-role key must remain on a trusted server and must never be embedded in an iOS binary.
- Rotate a credential immediately if it is exposed. Removing it from the latest commit is insufficient; revoke it first, then remove it from Git history with a coordinated history rewrite.

## Pre-push audit

Run:

```sh
HabitTracker/Scripts/security-audit.sh
```

The audit checks tracked filenames, the current tree, and every reachable Git revision for common high-confidence credential formats. GitHub also runs this audit for pull requests and pushes.

Automated pattern checks reduce risk but do not replace reviewing a diff before publishing it.

## Reporting a vulnerability

Do not open a public issue containing an undisclosed vulnerability or credential. Until a dedicated security contact is configured, use GitHub's private vulnerability-reporting feature for this repository. Include reproduction steps, affected versions, and impact without including unrelated personal data.

## Supported version

Security fixes apply to the latest commit on the active release branch. Vivere is still a release candidate and has not yet made a public App Store security-support commitment.
