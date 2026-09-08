# Dev Notch v1.0.0 Release Checklist

## 1. Automated Verification & Builds

- PASS — Tests 111/111
- PASS — Debug Build
- PASS — Release Build
- PASS — Helper Packaging (`DevNotchClaudeBridge` & `DevNotchActivityBridge` in `Contents/Helpers`)
- PASS — Hardened Runtime (Flags `0x10002(adhoc,runtime)` verified on app and helpers)
- PASS — No developer absolute paths (Verified in binary symbols and resources)
- PASS — No DerivedData references (Verified via `otool -L` on all binaries)
- PASS — MacBook Air M4 hardware notch layout (Content exclusion zone & wing layout)
- PASS — Antigravity real agy E2E (Verified with live `agy` execution and official hooks)
- PASS — Working visual dwell (Minimum 0.9s presentation dwell guaranteed)
- PASS — Completed transient (3.0s default transient, customizable via settings)

## 2. Desktop & System Integrations

- PASS — Finder Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Terminal Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Browser Hotkey (`⌃⌥Space` Carbon event registration verified)
- PASS — Launch at Login (`ServiceManagement.SMAppService` synchronization verified)

## 3. Packaging & Distribution Artifacts

- PASS — DMG (`dist/DevNotch-1.0.0.dmg`)
- PASS — SHA-256 (`49d07515123efaf8c39027bf5ef59325886976e8e77dde01ac3bcdeab1be98c3`)

## 4. Documentation & Policies

- PASS — README (Includes 4-step installation & Gatekeeper Open Anyway guidance)
- PASS — PRIVACY (Local-first architecture, no credential leakage)
- PASS — SECURITY (Zero embedded credentials, hook ownership isolation)
- PASS — CHANGELOG (v1.0.0 release notes documented)
- PASS — GitHub Release Notes (`GITHUB_RELEASE_NOTES.md` ready with highlights & SHA)

## 5. Non-Blocker Items / Excluded by Distribution Policy

- Developer ID: N/A — GitHub Direct Distribution
- Notarization: N/A — GitHub Direct Distribution
- Claude authenticated E2E: Optional / Pending if current machine remains unauthenticated (Do not treat as release blocker)
