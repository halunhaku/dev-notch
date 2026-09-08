# Changelog

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
