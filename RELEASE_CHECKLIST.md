# Dev Notch v1.0.0 Release Checklist

## 1. Distribution Policy & Strategy

- **Distribution Mode**: GitHub Direct Distribution (`PASS`)
- **Apple Developer Program / Developer ID**: `NOT APPLICABLE — GitHub unsigned distribution` (N/A by distribution policy)
- **Apple Notarization (`notarytool`)**: `NOT APPLICABLE — GitHub unsigned distribution` (N/A by distribution policy)
- **Ticket Stapling (`stapler`)**: `NOT APPLICABLE — GitHub unsigned distribution` (N/A by distribution policy)
- **Gatekeeper Notarization Acceptance**: `NOT APPLICABLE — GitHub unsigned distribution` (N/A by distribution policy)
- **macOS First-Launch Flow**: Documented via `System Settings -> Privacy & Security -> Open Anyway` (`PASS`)

## 2. Build & Packaging Verification

- **Release Build Configuration**: `PASS` (Optimized Release archive, Hardened Runtime enabled)
- **Code Signing Consistency**: `PASS` (Ad-hoc signed with runtime option)
- **Nested Helpers**:
  - `DevNotchClaudeBridge`: `PASS` (Present, executable, ad-hoc signed, runtime option, no external paths)
  - `DevNotchActivityBridge`: `PASS` (Present, executable, ad-hoc signed, runtime option, no external paths)
- **DerivedData / Developer Home Paths**: `PASS` (No `/Users/halunhaku` or `DerivedData` in bundle or dependencies)
- **DMG Package**: `PASS` (`dist/DevNotch-1.0.0.dmg`)
- **DMG Install Instructions**: `PASS` (`INSTALL.txt` included in DMG root)
- **SHA-256 Checksum**: `PASS` (`dist/DevNotch-1.0.0.dmg.sha256` generated and verified)

## 3. Automated Test Suite

- **Unit & Integration Tests**: `PASS` (All tests pass)
- **Release Readiness Suite**: `PASS` (Path audits, version parsing, provider registries, helper locations)
- **No Embedded Credentials / Fixtures**: `PASS` (Audited in bundle resources)

## 4. Documentation & Legal

- **README Installation Instructions**: `PASS` (Includes step-by-step install guide and macOS Security Notice)
- **GitHub Release Notes**: `PASS` (`GITHUB_RELEASE_NOTES.md` prepared with highlights and limitations)
- **Changelog**: `PASS` (`CHANGELOG.md` updated with v1.0.0)
- **Privacy Document**: `PASS` (`PRIVACY.md` accurate; no credential leakage observed)
- **Security Document**: `PASS` (`SECURITY.md` accurate; no credential leakage observed)
- **License**: `PASS` (MIT License preserved; no unauthorized changes)

## 5. Provider & Runtime Verification

- **OpenAI Codex**: `PASS` (Official app-server daemon and quota windows verified)
- **OpenCode Go**: `PASS` (CLI discovery and model windows verified)
- **DeepSeek**: `PASS` (Official balance API and token breakdown verified)
- **Anthropic Claude Code**:
  - Provider & Helper bridge: `PASS`
  - Unauthenticated fallback ("Sign in required"): `PASS`
  - Authenticated Live E2E: `PENDING USER VERIFICATION` (Requires signed-in Claude CLI on host)
- **Google Antigravity**:
  - CLI discovery & official hooks: `PASS`
  - Live task pulse flow: `PASS`
  - Live command execution verification: `PENDING USER VERIFICATION` (User execution of `agy`)

## 6. System & Desktop Integration Verification

- **Global Hotkey (`⌃⌥Space`)**:
  - Carbon event registration & toggle: `PASS`
  - Manual verification across Finder / Terminal / Browser: `PENDING USER VERIFICATION`
- **Menu Bar Status Item**: `PASS` (Verified in tests and preferences)
- **Launch at Login**:
  - `SMAppService` integration: `PASS`
  - System Settings Login Items confirmation in UI: `PENDING USER VERIFICATION`
- **Application Path Stability**: `PASS` (Integration guarded against DMG / Translocation paths)

## 7. Public Distribution Readiness

- **Status**: `PASS`
- Dev Notch v1.0.0 is fully ready for GitHub Direct Distribution release.
