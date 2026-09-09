# Dev Notch 1.1.0

Dev Notch is a native macOS Dynamic Island desktop application designed for AI developers. It integrates into your MacBook's physical notch (or virtual notch on external displays), delivering subtle, live AI status, quota monitoring, streaming Task Pulse, Now Playing, and quick controls.

## Highlights

- **Menu bar click-through**: The compact island no longer blocks the three status items immediately to the right of the hardware notch.
- **AI / System / Music tabs**: Shared expanded chrome, full-capsule tab hits, no layout jump.
- **Provider drag reorder** in Settings, mirrored on the expanded AI dashboard.
- **Grok**: `grok login` plus weekly SuperGrok credits from the CLI-proxy billing API.
- **One-click sign-in** on Codex, Claude, and Grok cards.
- **Now Playing**: Music tab and hover-while-playing for system Now Playing (including custom players that publish to Control Center).
- **Hardware notch-aware layout** with compact idle width matching the camera cutout.

## Installation

1. Download `DevNotch-1.1.0.dmg`.
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

This step is typically only required on the very first launch. We do **not** recommend disabling Gatekeeper globally.

## Verification & Integrity

Artifact: `DevNotch-1.1.0.dmg`
SHA-256 Checksum: `PENDING`
Checksum file: `DevNotch-1.1.0.dmg.sha256`

To verify the checksum in Terminal:
```bash
shasum -a 256 -c DevNotch-1.1.0.dmg.sha256
```

## Known Limitations

- **Now Playing**: Current macOS blocks MediaRemote inside compiled third-party binaries; Dev Notch uses an Apple-signed `swift` probe (Xcode or Command Line Tools on the Mac).
- **Claude subscription quota**: Not exposed through any stable machine-readable interface.
- **Antigravity subscription quota**: Google has not published an external quota API.
- **Grok credits**: Require a valid `grok login` session (`~/.grok/auth.json`).
