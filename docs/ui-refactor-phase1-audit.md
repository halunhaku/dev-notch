# Phase 1 — UI Architecture Audit

目标：Concept B · Pro Dashboard。范围：View 层重构。不改 Provider 检测、quota、hooks、System Insights 采样、Music 探测。

当前版本：`MARKETING_VERSION 1.1.2` / `CURRENT_PROJECT_VERSION 5`。macOS 14+，SwiftUI + AppKit overlay。无第三方 UI 库。无 `DevNotchTheme`。

---

## 当前 UI 树

```
NotchView                          岛体黑底 + 内描边 + TaskPulse
├── CompactNotchView               物理刘海翼 / 虚拟条
│   └── AICompactStatusView        主 Provider compactMetric
├── HoveredNotchView               标题 + 状态点 + 歌曲或 quota 字幕
└── ExpandedNotchView              顶栏 + segmented tabs + 三页叠层
    ├── aiDashboard                等大 AIProviderCard 纵向列表
    ├── SystemInsightsView         已是 2×2 + sparkline
    └── NowPlayingView             单列封面 + 进度 + 三键控制
```

Settings 是独立 `TabView` 窗口（520×420）：General / AI Providers / Integrations / About。

---

## 文件分类

### 必须改（纯 View）

| 文件 | 现状 | Concept B |
|---|---|---|
| `Views/NotchView.swift` | 黑岛 + 0.5 内描边，无投影 | 保留岛形约束；accent 改蓝紫 |
| `Views/CompactNotchView.swift` | 只包 compact metric | 动态信息条 |
| `Views/AI/AICompactStatusView.swift` | 翼：点+label / 值 | 见下方刘海冲突 |
| `Views/HoveredNotchView.swift` | 标题+状态+歌曲或 quota | 收成 pill：Icon \| Dev Notch \| ⚡ Grok 77% \| ♫ 歌 \| ● \| Chevron |
| `Views/ExpandedNotchView.swift` | 顶栏 + 白胶囊 tab + 等大卡片列表 | 分段 nav + 主/次 Provider 仪表盘 |
| `Views/AI/AIProviderCard.swift` | 所有 Provider 同一大卡片 | 拆 Primary / Secondary |
| `Views/AI/AIUsageBar.swift` | 6pt cyan 渐变条 | 更细；accent 蓝紫；低配额橙/红 |
| `Views/System/SystemInsightsView.swift` | 已 2×2，标题「System Insights」 | 去掉页内标题；数字更大；sparkline 降权 |
| `Views/Music/NowPlayingView.swift` | 单列 92pt 封面 + prev/play/next | 左 Now Playing / 右 Queue |
| `Settings/Views/SettingsView.swift` | 系统 TabView | 可保留系统 Tab（HIG）或自制分段 |
| `Settings/Views/ProvidersSettingsView.swift` | Toggle+名称+inline token | 行：drag / icon / via / Primary / Ready / toggle / 设置 |
| `Views/Notch/TaskPulseView.swift` | cyan 呼吸线 | accent 对齐；Reduce Motion 已有 |

### 可复用（改 tokens，不改结构）

- `AIBalanceView` / `AICreditsView` / `AIContextView` / `AISessionCostView` — 次级 metric
- `SystemMetricCard` + `SystemSparklineShape` — System 2×2
- `FullAreaPlainButtonStyle`
- Hardware notch 翼布局（`HardwareNotchModel.leftWingWidth`）

### 需要新增

| 组件 | 用途 |
|---|---|
| `DevNotchTheme` | radius / padding / spacing / text / card / accent / success / warning / critical |
| `DNCard` / `DNHairline` | 圆角卡片 + 极弱边框 |
| `DNMetricText` | 等宽数字大字号 |
| `DNStatusPill` | Ready / Warning 绿橙红 |
| `DNProgressBar` | 细进度条，Provider 色仅用于 fill |
| `PrimaryProviderCard` | 大主卡：icon / badge / plan / via / Ready / % / bar / reset / updated |
| `SecondaryProviderCard` | 底栏小卡：名 / Ready / % / bar |
| `QuickActionsPanel` | 打开对话 / 使用记录 / 用量分析 — **无真实功能则 disabled** |
| `WeeklyUsageRanking` | 排行 UI；无独立用量数据则空态，不伪造 |
| `SegmentedIslandNav` | ✨ AI / 〽 系统 / ♫ 音乐，选中蓝紫 glow |
| `CompactStatusStrip` | 动态 pill 内容 |
| `NowPlayingHero` + `PlaybackTransport` | 封面 / 进度 / 中心 Play |
| `ProviderSettingsRow` + `ProviderDetailSheet` | 主列表去 token；配置进 sheet |

### 业务逻辑必须不动

| 层 | 文件 | 原因 |
|---|---|---|
| Provider 编排 | `AI/Services/AIProviderManager.swift` + Registry | snapshot / primary / order / refresh / sign-in / live activity |
| 各 Provider | `AI/Providers/**` | 检测、quota、auth、hooks |
| 模型 | `AI/Models/**` | `AIProviderSnapshot`、`AIUsageWindow`、`AICompactMetric` |
| System | `System/SystemMetricsStore.swift` | **仅 System 页可见时 1Hz 采样** |
| Music 探测 | `Music/NowPlayingStore.swift`、`MediaRemoteClient.swift`、helper | 现有 Now Playing |
| Notch 状态机 | `Notch/NotchModel.swift` | compact ↔ hovered ↔ expanded；hover debounce；2s auto-collapse |
| 几何 | `Notch/NotchGeometry.swift` | 硬件刘海翼、hit-test、window frame。**改尺寸必须同步测试** |
| Prefs | `PreferencesStore`、`LaunchAtLoginManager`、`GlobalHotKeyManager` | |
| 岛形约束 | `NotchView` 无全方位 shadow | 已修 rim；不要加 drop shadow |

公开 UI 可调用、无需改 Manager：

- `enabledProviderIDs` / `snapshots` / `preferredPrimaryID` / `primaryCompactMetric` / `primarySnapshot`
- `setPrimaryProvider` / `applyProviderOrder` / `refresh` / `signIn` / `toggleClaudeLiveActivity` / `toggleAntigravityLiveActivity`
- `snapshot.primaryRemainingPercent`、`account.displayPlanName`、`credentialSource`、`metrics`
- `NowPlayingStore.togglePlayPause/next/previous` + `info`（title/artist/album/artwork/elapsed/duration）
- `SystemMetricsStore.setActive` + snapshot/history

---

## 与 Concept B 的硬冲突（实施前必须拍板）

### 1. 展开画布太小（阻塞所有 Dashboard 页）

当前 `NotchGeometry.visualSize(.expanded)`：

- 有刘海：宽 `max(420, hardwareNotchWidth+240)`，高 `340 + contentTopInset`
- 无刘海：`420 × 340`

Concept B 是主卡 + 右侧双面板 + 底栏三小卡。420×340 塞进去会严重压缩，不像参考图。

测试会钉死几何：`HardwareNotchLayoutTests`（compact 必须等于硬件刘海宽、翼不可点、展开内容在刘海下）。

### 2. 硬件刘海 compact ≠ 参考图 pill

有刘海时 compact **必须等于摄像头宽度**，内容只能在左右翼，中间是排除区。不能在 compact 显示 `Icon | Dev Notch | ⚡ Grok 77% | ♫ 歌`。

参考图那条 pill 只能映射到：

- 无刘海 / 外接屏的 compact/hovered
- 或有刘海的 **hovered**（刘海下方那一行）

### 3. 没有这些真实数据 / API

| 参考图 | 现状 | 处理 |
|---|---|---|
| 快速操作：打开对话 / 使用记录 / 用量分析 | 无 | 布局可做，按钮 disabled，不写假业务 |
| 本周使用排行 | 只有各 Provider **剩余配额 %**，不是使用量排行 | 不拿 remaining% 冒充排行 |
| Playlist / Queue | `NowPlayingInfo` 只有当前曲 | 无 queue 则右侧隐藏/空态 |
| shuffle / repeat / volume / 输出设备 | `NowPlayingCommand` 仅 play/pause/next/prev | 不接 private 新 API；无数据则不画或 disabled |
| 收藏 / more menu | 无 | 同上 |

MediaRemote 已是 private API（GitHub 分发，非 App Store）。不扩大 private API 面。

### 4. Settings chrome vs HIG

参考图是自定义分段 + 深色列表。现有是系统 `TabView` + grouped Form，符合 macOS Settings。冲突时 HIG 优先 → **保留系统 TabView 外壳**，只重构 Provider 行和把 token 移出主列表。

---

## 建议的实施边界（待确认）

1. **展开岛放大到约 720×460**（仍贴屏幕上沿，不是独立 App 窗口）。compact 硬件尺寸不动。
2. **Concept B compact pill = hovered + 无刘海 compact**。有刘海 compact 仍是翼内 metric。
3. **Quick actions / 排行 / queue / volume**：有数据才启用；否则空态或隐藏，不伪造。
4. **Settings**：系统 Tab 保留；Provider 行按参考图；OpenCode token / Grok login 进 sheet。
5. **Theme**：新建 `DevNotch/Theme/DevNotchTheme.swift`，先落地再改 View。
6. 不改 Provider/System/Music 服务；不改自动折叠/hover 状态机；不加第三方 UI；岛体不加 drop shadow。

---

## Phase 顺序（确认后执行）

2. Shared Design System → 3. Notch Shell → 4. AI Dashboard → 5. System → 6. Music → 7. Settings → 8. Animation & Polish → 9. Build/Test

每 Phase 完跑 build + 相关 tests。几何一改就跑 `HardwareNotchLayoutTests`。
