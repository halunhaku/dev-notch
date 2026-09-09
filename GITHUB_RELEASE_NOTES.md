# Dev Notch 1.1.1

MacBook 物理刘海上的 AI Dynamic Island。本版增加应用内语言：跟随系统 / English / 简体中文，设置、刘海、菜单栏立刻切换。

In-app language: Follow System, English, or 简体中文. Applies immediately to Settings, the island, and the menu bar.

## 截图

![收起态刘海](https://github.com/halunhaku/dev-notch/releases/download/v1.1.1/compact.png)

![展开 · AI](https://github.com/halunhaku/dev-notch/releases/download/v1.1.1/expanded-ai.png)

![展开 · Music](https://github.com/halunhaku/dev-notch/releases/download/v1.1.1/music.png)

![展开 · System](https://github.com/halunhaku/dev-notch/releases/download/v1.1.1/system.png)

## 本版更新

- **语言**：设置 → 通用 → 语言。跟随系统 / English / 简体中文，立刻生效。
- 品牌名（Dev Notch、Codex、Grok 等）不翻译。

## Highlights

- **Language**: Settings → General → Language. Follow System, English, or 简体中文; no restart.
- Brand names stay untranslated.

1.1.0 已包含：菜单栏点透、AI / System / Music 三页签、Provider 拖拽排序、Grok 周额度、Now Playing。

## 安装 / Installation

1. 下载 `DevNotch-1.1.1.dmg`。
2. 打开 DMG。
3. 把 `Dev Notch` 拖进 `/Applications`（或 `~/Applications`）。
4. 从「应用程序」启动。

> **注意**：启用 Claude / Antigravity 集成或「登录时打开」前，App 必须在 `/Applications` 或 `~/Applications`。

## macOS 安全提示 / Security Notice

Dev Notch 通过 GitHub 直接分发，**没有** Apple Developer ID 签名，也未经公证。

第一次启动时 Gatekeeper 可能拦截。打开方式：

1. 先尝试启动（初始弹窗点 **Done** 或 **Cancel**）。
2. 打开 **系统设置 → 隐私与安全性**。
3. 在 **安全性** 里找到 Dev Notch，点 **仍要打开 / Open Anyway**。
4. 输入密码或 Touch ID，再点 **打开**。

通常只在第一次需要。不要为了这个 App 全局关闭 Gatekeeper。

## 校验 / Verification

Artifact: `DevNotch-1.1.1.dmg`  
SHA-256: `3fbc4d84bd680d3b9b90bbf23b55ebe78c85e23d9dcb41f5cc698ae0b1cfc21e`  
Checksum file: `DevNotch-1.1.1.dmg.sha256`

```bash
shasum -a 256 -c DevNotch-1.1.1.dmg.sha256
```

## 已知限制 / Known Limitations

- **Now Playing**：当前 macOS 会拦截第三方编译产物里的 MediaRemote；Dev Notch 走 Apple 签名的 `swift` 探测（本机需 Xcode 或 Command Line Tools）。
- **Claude 订阅额度**：没有稳定的机器可读接口。
- **Antigravity 订阅额度**：Google 未公开外部配额 API。
- **Grok 额度**：需要有效的 `grok login` 会话（`~/.grok/auth.json`）。
