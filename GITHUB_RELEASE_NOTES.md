# Dev Notch 1.0.0

Dev Notch is a native macOS Dynamic Island desktop application designed for AI developers. It integrates into your MacBook's physical notch (or virtual notch on external displays), delivering subtle, live AI status, quota monitoring, streaming Task Pulse, and quick controls.

## Highlights

- **Native MacBook Notch Interface**: Three-state interaction (Compact, Expanded, and Floating island mode for external displays).
- **Codex Quota Monitoring**: Live tracking of 5-hour rolling limit and weekly usage quotas via local official app-server.
- **DeepSeek Balance Monitoring**: Real-time account balance, top-up balance, and grant balance via official API.
- **Claude Code Activity Integration**: Official CLI hook bridge capturing working sessions and context token metrics.
- **Google Antigravity Activity Integration**: Official `agy` hook integration capturing live development activity and session states.
- **OpenCode Go Integration**: Model window status and local CLI detection.
- **Generic AI Activity Status**: Normalized activity model supporting multiple concurrent developer agents.
- **Task Pulse**: Sub-pixel ambient halo along notch contour (Working pulse, Approval steady amber, Completed burst). Full `Reduce Motion` accessibility support.
- **Zero-Permission Global Hotkey**: Carbon-based `⌃⌥Space` (Control + Option + Space) to toggle notch anywhere without Accessibility or Input Monitoring permissions.
- **Menu Bar Status Item**: Native NSStatusItem presenting multi-provider snapshot and fast settings access.
- **Native Settings Panel**: Multi-tab native SwiftUI Settings (General, AI Providers, Integrations, About).
- **Launch at Login**: Native `ServiceManagement.SMAppService` synchronization with macOS Login Items.
- **Bundled Helper Architecture**: Pre-compiled, ad-hoc signed Swift CLI helpers embedded in `DevNotch.app/Contents/Helpers/`.

## Installation

1. Download `DevNotch-1.0.0.dmg`.
2. Open the DMG.
3. Drag `Dev Notch` into `/Applications` (or `~/Applications`).
4. Launch Dev Notch from Applications.

> **Note**: Dev Notch must reside in `/Applications` or `~/Applications` before enabling Claude / Antigravity integrations or Launch at Login.

## macOS Security Notice

Dev Notch is distributed directly via GitHub and is not signed with an Apple Developer ID or notarized by Apple.

When launching Dev Notch for the first time, macOS Gatekeeper may display a verification prompt. To open:
1. Attempt to launch Dev Notch (click **Done** or **Cancel** on the initial alert).
2. Go to **System Settings** -> **Privacy & Security**.
3. Under **Security**, find the prompt for Dev Notch and click **Open Anyway** (仍要打开).
4. Enter your Mac user password or use Touch ID, then click **Open**.

This step is typically only required on the very first launch.

## Verification & Integrity

Artifact: `DevNotch-1.0.0.dmg`
Checksum file: `DevNotch-1.0.0.dmg.sha256`

To verify the checksum in Terminal:
```bash
shasum -a 256 -c DevNotch-1.0.0.dmg.sha256
```

## Known Limitations

- **Claude subscription quota**: Not exposed through any stable machine-readable interface; provider focuses on session activity metrics.
- **Antigravity subscription quota**: Google has not published an external quota API for Antigravity; provider focuses on official CLI hooks and activity status.
- **Claude authenticated Activity E2E**: Fully implemented and tested via mock hooks; end-to-end live testing with Claude CLI requires an authenticated Claude Code account on the host machine.
