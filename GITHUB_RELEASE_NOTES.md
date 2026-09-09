# Dev Notch 1.1.2

MacBook 物理刘海上的 AI Dynamic Island。本版去掉悬停 / 展开时岛体左右和下沿那圈浅黑边。

Patch release: remove the faint black rim around hovered and expanded island edges.

## 本版更新

- **岛体边缘**：悬停 / 展开不再用全方位投影，左右和下沿不再多一圈浅黑描边；白描边改为内描。

## Highlights

- **Island edge**: Drop the omnidirectional shadow that bloomed around the bezel-attached island; inset the hairline with `strokeBorder`.

1.1.1 已包含：应用内语言（跟随系统 / English / 简体中文）。
1.1.0 已包含：菜单栏点透、AI / System / Music 三页签、Provider 拖拽排序、Grok 周额度、Now Playing。

## 安装 / Installation

1. 下载 `DevNotch-1.1.2.dmg`。
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

Artifact: `DevNotch-1.1.2.dmg`  
SHA-256: `0ee73f4ec154cb699586a51d1e6f7f5cee1668a50463d497db07d9000b22d73d`  
Checksum file: `DevNotch-1.1.2.dmg.sha256`

```bash
shasum -a 256 -c DevNotch-1.1.2.dmg.sha256
```

## 已知限制 / Known Limitations

- **Now Playing**：当前 macOS 会拦截第三方编译产物里的 MediaRemote；Dev Notch 走 Apple 签名的 `swift` 探测（本机需 Xcode 或 Command Line Tools）。
- **Claude 订阅额度**：没有稳定的机器可读接口。
- **Antigravity 订阅额度**：Google 未公开外部配额 API。
- **Grok 额度**：需要有效的 `grok login` 会话（`~/.grok/auth.json`）。
