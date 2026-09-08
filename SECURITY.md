# Security

## Reporting a vulnerability

This repository does not yet publish a dedicated security contact. Before public release, configure GitHub private vulnerability reporting and document the resulting reporting route here. Do not include credentials or sensitive reproduction data in a public issue.

## Credential handling

- Dev Notch does not persist provider credentials in its own preferences.
- Existing credentials are read only from provider-owned local configuration when required.
- Credentials, prompts, responses, source code, and tool results must not be logged.
- Developer ID and notarization credentials stay in the macOS Keychain or protected environment variables and are never committed.

## Local integration model

Claude and Antigravity integrations add only entries marked as owned by Dev Notch. Updating or uninstalling an integration must not modify user or third-party hooks. Hook commands resolve helper executables from the installed DevNotch application bundle.

Integration installation and Launch at Login are blocked until the app is under `/Applications` or `~/Applications`, preventing persistent references to a DMG, Downloads folder, or App Translocation path.
