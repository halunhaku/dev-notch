# Dev Notch 1.1.0

MacBook 物理刘海上的 AI Dynamic Island。额度、Task Pulse、Now Playing、系统指标；收起时不再挡住右侧菜单栏图标。

A native macOS Dynamic Island for AI developers: live quota, Task Pulse, Now Playing, and system metrics. The compact island no longer blocks the status items to the right of the hardware notch.

## 截图

![收起态刘海](https://github.com/halunhaku/dev-notch/releases/download/v1.1.0/compact.png)

![展开 · AI](https://github.com/halunhaku/dev-notch/releases/download/v1.1.0/expanded-ai.png)

![展开 · Music](https://github.com/halunhaku/dev-notch/releases/download/v1.1.0/music.png)

![展开 · System](https://github.com/halunhaku/dev-notch/releases/download/v1.1.0/system.png)

## 本版更新

- **菜单栏点透**：收起态不再挡住刘海右侧三个状态图标。
- **AI / System / Music 三页签**：同一套展开外壳，整颗胶囊可点，切换不跳布局。
- **Provider 拖拽排序**：设置里排序，展开 AI 列表同步。
- **Grok**：`grok login` + SuperGrok 周额度（CLI billing API）。
- **一键登录**：Codex / Claude / Grok 卡片可直接拉起登录。
- **Now Playing**：Music 页 + 播放中悬停预览（含向控制中心上报的第三方播放器）。
- **硬件刘海贴合**：收起宽度对齐摄像头开孔。

## Highlights

- **Menu bar click-through**: compact island no longer blocks the three status items immediately right of the hardware notch.
- **AI / System / Music tabs**: shared expanded chrome, full-capsule tab hits, no layout jump.
- **Provider drag reorder** in Settings, mirrored on the expanded AI dashboard.
- **Grok**: `grok login` plus weekly SuperGrok credits from the CLI-proxy billing API.
- **One-click sign-in** on Codex, Claude, and Grok cards.
- **Now Playing**: Music tab and hover-while-playing for system Now Playing (including custom players that publish to Control Center).
- **Hardware notch-aware layout** with compact idle width matching the camera cutout.

## 安装 / Installation

1. 下载 `DevNotch-1.1.0.dmg`。
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

Artifact: `DevNotch-1.1.0.dmg`  
SHA-256: `f6a825c601af418fc1ca15aae8a5f570fd5fa390ee4b144d4db056414bdc0df1`  
Checksum file: `DevNotch-1.1.0.dmg.sha256`

```bash
shasum -a 256 -c DevNotch-1.1.0.dmg.sha256
```

## 已知限制 / Known Limitations

- **Now Playing**：当前 macOS 会拦截第三方编译产物里的 MediaRemote；Dev Notch 走 Apple 签名的 `swift` 探测（本机需 Xcode 或 Command Line Tools）。
- **Claude 订阅额度**：没有稳定的机器可读接口。
- **Antigravity 订阅额度**：Google 未公开外部配额 API。
- **Grok 额度**：需要有效的 `grok login` 会话（`~/.grok/auth.json`）。
