# Vivere Launch Security Checklist

Complete this checklist before an App Store submission, TestFlight release, or public repository update.

1. **Hide private API keys.** No privileged key may appear in source, configuration committed to Git, build logs, screenshots, documentation, or the compiled app.
2. **Scan the complete Git history.** Run `Scripts/security-audit.sh`, not just a search of the working tree.
3. **Revoke before purging.** If a secret is ever exposed, revoke or rotate it before rewriting history; assume clones and caches retain the old value.
4. **Use only publishable client keys in an app.** Never ship database admin, service-role, signing, or unrestricted server keys in an iOS binary.
5. **Keep Vivere local-first.** The current app needs no API or database key. Adding a hosted backend requires a fresh threat and privacy review.
6. **Apply least privilege.** Keep entitlements limited to capabilities the shipping target uses. Review the App Group, notifications, Photos picker, App Intents, widgets, and Watch connectivity.
7. **Separate build configurations.** If remote services are added, use private local/CI configuration injection and distinct development and production credentials.
8. **Protect signing material.** Never commit `.p12`, `.p8`, `.cer`, `.pem`, `.key`, provisioning-profile, or keychain export files.
9. **Minimize dependencies.** Vivere currently uses Apple frameworks only. Review ownership, license, update policy, and advisories before adding a package.
10. **Use encrypted transport.** Any future network request must use HTTPS with App Transport Security intact; document every exception.
11. **Validate untrusted imports.** Keep backup restoration schema-validated, size-bounded, non-destructive, and covered by malformed-input tests.
12. **Preserve data safely.** Test Core Data lightweight migrations from every supported model and never silently replace an unreadable store.
13. **Protect exported data.** Backups and shared journal content leave the sandbox only after an explicit user action through an Apple system picker or share sheet.
14. **Request permissions in context.** Ask only for capabilities the user invokes, explain their purpose, and handle denial without crashing.
15. **Avoid sensitive logging.** Do not log journal text, habit notes, photo data, notification content, identifiers, or restored backup payloads.
16. **Harden destructive actions.** Confirm deletion, define whether it is recoverable, and test deletion across iPhone, widget snapshots, Watch state, and backups.
17. **Test failure paths.** Cover unavailable App Groups, denied notifications, unavailable Watch sessions, corrupt backups, migration failures, and low-storage saves.
18. **Verify release configuration.** Archive with the intended bundle identifiers, production signing, no debug flags, no test data, and no unintended entitlements.
19. **Complete privacy disclosures.** Keep `PRIVACY.md`, App Store privacy answers, permission strings, data-retention behavior, and actual code behavior consistent.
20. **Run the release gate.** Review `git diff`, run builds and tests for iPhone/widget/Watch, execute the security audit, inspect the archive, and perform a real-device smoke test before submission.

## Current key decision

Vivere stores its source-of-truth data in local Core Data. It has no public or private database key, so “use a public DB key” is currently **not applicable**. This is safer than adding a backend solely to satisfy a generic checklist.
