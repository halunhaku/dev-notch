# Dev Notch 1.1.3

本版重做展开岛的三页布局：统一高度、完整避开实体刘海，并提升 AI、系统状态与音乐控制的视觉密度和一致性。

This release rebuilds the three expanded dashboard pages around one stable, notch-safe canvas with a more polished AI dashboard, System grid, and Now Playing experience.

## 本版更新

- **统一展开尺寸**：AI / 系统 / 音乐固定使用同一画布，切页时岛体不再跳高。
- **刘海安全区**：品牌、页签、设置与收起按钮统一放到实体刘海下方，不再被摄像头区域遮挡。
- **AI 仪表盘**：主 Provider 信息突出；次 Provider 自动平衡为满宽网格，内容超高时可自然滚动。
- **系统状态**：CPU、内存、网络、电池固定为等高 2×2 卡片，曲线和状态信息对齐。
- **音乐控制**：放大封面，重新整理歌曲信息、进度、播放控制、系统音量与输出设备。
- **Provider 设置**：Provider 列表显示来源、主 Provider、状态与快捷操作；详细配置移入独立面板。

## Highlights

- **Stable expanded canvas**: AI, System, and Music now share one fixed height, so tab changes no longer resize the island.
- **Physical-notch clearance**: the complete toolbar sits below the camera cutout.
- **Balanced dashboards**: full-width provider rows, equal System cards, and scroll-safe AI content.
- **Now Playing polish**: larger artwork, clearer playback hierarchy, system volume, output-device context, and source-app access.
- **Provider settings**: denser status rows with dedicated detail sheets.

## 安装 / Installation

1. 下载 `DevNotch-1.1.3.dmg`。
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

Artifact: `DevNotch-1.1.3.dmg`
SHA-256: `86e1c7d9e3037f44bf7a784166e4f9c822e54e7094eb1440d37989f5c9855b92`
Checksum file: `DevNotch-1.1.3.dmg.sha256`

```bash
shasum -a 256 -c DevNotch-1.1.3.dmg.sha256
```

## 已知限制 / Known Limitations

- **Now Playing**：当前 macOS 会拦截第三方编译产物里的 MediaRemote；Dev Notch 走 Apple 签名的 `swift` 探测（本机需 Xcode 或 Command Line Tools）。
- **Claude 订阅额度**：没有稳定的机器可读接口。
- **Antigravity 订阅额度**：Google 未公开外部配额 API。
- **Grok 额度**：需要有效的 `grok login` 会话（`~/.grok/auth.json`）。
