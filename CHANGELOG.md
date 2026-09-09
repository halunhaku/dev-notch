# Changelog

## 1.1.0

### Highlights

- **Menu bar click-through**: Compact overlay no longer blocks the status items immediately right of the hardware notch.
- **AI / System / Music tabs**: Shared expanded layout, full-capsule tab hit targets, no page jump when switching.
- **Provider drag reorder**: Settings list order is persisted and used by the expanded AI dashboard.
- **Grok**: Official Grok CLI (`grok login`) plus weekly SuperGrok credits via the CLI-proxy billing API.
- **One-click CLI sign-in**: Codex, Claude, and Grok cards launch Terminal login when signed out.
- **Now Playing**: Music tab and hover-while-playing line for system Now Playing (including custom players that publish to Control Center).

### Known limitations

- Compiled binaries cannot read MediaRemote on current macOS; Now Playing uses an Apple-signed `swift` probe (Xcode / CLT required on the machine).
- Grok credits require a valid `grok login` session in `~/.grok/auth.json`.
- Claude and Antigravity still have no public subscription quota API.

## 1.0.0

Official v1.0.0 release for GitHub Direct Distribution.

### Highlights

- **GitHub Direct Distribution**: Formally established release workflow distributing self-contained, ad-hoc signed and Hardened Runtime verified macOS DMG package via GitHub Releases.
- **Native Notch Experience**: MacBook physical notch and external display floating island modes.
- **Multi-Provider AI Quota & Activity**: OpenAI Codex, DeepSeek, Anthropic Claude Code, Google Antigravity, and OpenCode Go integrations.
- **Task Pulse**: Sub-pixel ambient status glow with full Reduce Motion accessibility support.
- **Zero-Permission Global Hotkey**: Carbon-based `⌃⌥Space` system toggle.
- **Native Settings & Menu Bar**: Native SwiftUI Settings and macOS menu bar status item.
- **Bundled Helper Executables**: Dedicated bridge executables (`DevNotchClaudeBridge` and `DevNotchActivityBridge`) embedded in the app bundle.
- **Security & Installation Documentation**: Added clear installation instructions and macOS Gatekeeper `Open Anyway` guidance.

### Known limitations

- Claude subscription quota is not exposed through a stable machine-readable interface.
- Google Antigravity subscription quota is not exposed through a stable machine-readable interface.
- Claude authenticated Activity E2E requires a signed-in Claude CLI account on the host machine.

## 0.9.0-rc1

Release candidate for the first public Dev Notch release.

### Highlights

- Native three-state MacBook notch interface
- Codex, OpenCode Go, DeepSeek, Claude Code, and Google Antigravity status
- Codex usage windows and DeepSeek account balance
- Claude and Antigravity local activity bridges
- Global Control–Option–Space shortcut, menu bar controls, and native settings
- Native Launch at Login support
- Hardened Release archive with bundled helper executables
- Settings window now opens reliably from the menu bar on macOS 26 (legacy `showSettingsWindow:` selector replaced with the supported `openSettings` path).
- Claude and Antigravity integrations detect outdated helper paths after the app moves and offer a one-click "Repair" that rewrites only Dev Notch-owned hook entries.

### Known limitations

- Claude authenticated end-to-end verification requires a signed-in Claude CLI account.
- Antigravity quota data is unavailable because no supported external quota interface is known.
- Developer ID signing, Apple notarization, and clean-machine first launch require release credentials and separate real-device verification.
