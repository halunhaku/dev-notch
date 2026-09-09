# Dev Notch v1.1.3 Release Checklist

## 1. Automated Verification & Builds

- PASS — Tests (run via `./script/release.sh github`)
- PASS — Debug Build
- PASS — Release Build
- PASS — Helper Packaging (`DevNotchClaudeBridge`, `DevNotchActivityBridge`, `DevNotchNowPlaying` in `Contents/Helpers`)
- PASS — Hardened Runtime on app and CLI bridges (`DevNotchNowPlaying` unsigned-runtime by design for MediaRemote)
- PASS — No developer absolute paths
- PASS — No DerivedData references
- PASS — Hardware notch click-through for right-of-notch menu extras
- PASS — Grok CLI credits path
- PASS — Now Playing via system MediaRemote probe
- PASS — Hovered/expanded island has no omnidirectional drop shadow rim

## 2. Desktop & System Integrations

- PASS — Finder Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Terminal Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Browser Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Launch at Login (`ServiceManagement.SMAppService` synchronization verified)

## 3. Packaging & Distribution Artifacts

- PASS — DMG (`dist/DevNotch-1.1.3.dmg`)
- PASS — SHA-256 `86e1c7d9e3037f44bf7a784166e4f9c822e54e7094eb1440d37989f5c9855b92`

## 4. Documentation & Policies

- PASS — README (Includes 4-step installation & Gatekeeper Open Anyway guidance)
- PASS — PRIVACY (Local-first architecture, Grok billing token, Now Playing metadata)
- PASS — SECURITY (Zero embedded credentials, hook ownership isolation)
- PASS — CHANGELOG (v1.1.3 release notes documented)
- PASS — GitHub Release Notes (`GITHUB_RELEASE_NOTES.md`)

## 5. Non-Blocker Items / Excluded by Distribution Policy

- Developer ID: N/A — GitHub Direct Distribution
- Notarization: N/A — GitHub Direct Distribution
- Claude authenticated E2E: Optional / Pending if current machine remains unauthenticated (Do not treat as release blocker)
