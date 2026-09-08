# Dev Notch

**Dev Notch** 是专为 macOS 设计的原生「AI Developer Dynamic Island」桌面应用。它巧妙利用 MacBook 的物理刘海区域（并在无刘海屏幕上自适应为顶部虚拟岛），为开发者提供沉浸、轻量且无打扰的 AI 运行状态、任务提醒与快捷控制中心。

---

## 📌 当前开发阶段

- **Phase 1：原生刘海窗口底座与三态交互（已完成）**
- **Phase 2：AI Provider 架构与 Codex Provider 真实接入（已完成）**

---

## 🛠 技术栈

- **开发语言**：100% Swift 5.9+ / Swift 6 现代并发规范（Actor 隔离、Sendable 检查）
- **UI 框架**：SwiftUI
- **窗口系统**：AppKit（`NSPanel` + `NSHostingView` + `NSWindowController`）
- **构建工具**：`xcodegen` + `xcodebuild` + `XCTest`
- **目标平台**：macOS 14.0+ (Sonoma / Sequoia)
- **适配架构**：Apple Silicon (arm64) 原生支持
- **设计哲学**：0 第三方运行时框架，0 Node.js/Electron，纯正 macOS 原生手感，Local-First 安全设计

---

## 🚀 如何 Build & Run & Test

### 编译并启动应用
```bash
./script/build_and_run.sh
```

### 运行单元测试套件
```bash
xcodebuild -project DevNotch.xcodeproj -scheme DevNotch -destination 'platform=macOS' test
```

同时已配置 `.codex/environments/environment.toml`，在 Codex 环境下可通过 Run 动作一键触发构建与启动。

---

## ✨ 当前已实现功能

### 1. 原生刘海窗口底座（Phase 1）
- **多显示器与安全区域检测**：通过 `ScreenManager` 与 `NotchGeometry` 精确读取 `NSScreen.safeAreaInsets`、`auxiliaryTopLeftArea` 与 `auxiliaryTopRightArea`。
- **物理刘海贴合与外接屏自适应**：在刘海屏上贴合物理刘海宽度（~179pt），在无刘海显示器上呈现顶部虚拟 Dynamic Island。
- **非激活式顶级悬浮窗口**：基于 `.statusBar` 层级，覆盖普通应用但绝不抢夺键盘焦点（`canBecomeKey = false`），支持跨虚拟桌面常驻与全屏辅助显示。
- **流畅三态交互模型**：`compact`（紧凑贴合）、`hovered`（悬停预览）、`expanded`（展开看板），配备 160ms 防抖收起与点击外部区域（Outside Click）自动折叠。

### 2. AI Provider 统一架构（Phase 2）
- **高扩展性 Provider 协议**：设计了统一的 `AIProvider` 协议，UI 仅与通用模型（`AIProviderStatus`、`AIAccount`、`AIUsage`、`AIUsageWindow`）交互，完全解耦具体 AI 厂商实现。
- **中心化状态管理**：`AIProviderManager` 统一管理应用级 AI 状态、定时回退刷新与实时更新广播。

### 3. OpenAI Codex 真实数据驱动（Phase 2）
- **官方 App-Server 管道通信**：不触碰用户 API Key 或私密 Token，通过 `Process` 启动本地官方 `codex app-server`，使用 `stdin/stdout` 进行 JSON-RPC 2.0（JSONL）双向异步通信。
- **可靠的可执行文件发现**：`CodexExecutableLocator` 跨 Homebrew、NVM、Cargo、PATH 以及登录 Shell 多层探测，并自动注入补全子进程运行环境，杜绝 GUI 模式下的 PATH 丢失与 Exit 127 错误。
- **Actor 隔离的子进程与 RPC 管理**：`CodexAppServer` Actor 严格隔离并发状态，保证 Request ID 分发、Continuation 超时看门狗与行流解析完全无数据竞争。
- **真实账户与配额读取**：
  - 调用 `account/read` 获取当前 ChatGPT 登录邮箱与 Plan 类型（如 Plus）。
  - 调用 `account/rateLimits/read` 获取 5 小时与 Weekly 配额。
  - 监听 `account/rateLimits/updated` 保持后台实时响应。
- **精确的使用率与重置时间语义**：
  - 明确区分解析 `usedPercent` 与计算 `remainingPercent`（100 - usedPercent），UI 优先向用户呈现剩余额度。
  - 动态计算时间窗口（如 300 分钟自适应为 `5 Hour`，10080 分钟自适应为 `Weekly`）。
  - 格式化本地化倒计时（如 `Reset in 2h 14m`）与用户时区绝对时间（如 `Resets Tue 08:00`）。
- **完整交互态适配**：
  - **Compact**：显示微型状态指示灯与当前剩余百分比（如 `</> 100%`）。
  - **Hovered**：显示 Provider 名称、剩余配额与交互提示。
  - **Expanded**：展示完整的 `AIProviderCard`，包含双配额进度条、Plan 标签、更新时间与手动刷新按钮。

---

## 🧪 自动化测试（XCTest）

工程内置独立单元测试目标 `DevNotchTests`，覆盖：
- `AIUsageWindowTests`：时间窗口动态标签、剩余百分比截断计算、相对倒计时与时区绝对时间格式化。
- `CodexParsingTests`：真实的 JSON-RPC Account 结果、RateLimits 结果、Notification 推送以及 RPC 异常结构解析与向前兼容性。
- `AIProviderStatusTests`：状态枚举短描述、可用性判断与 Provider ID 映射。

---

## 🔮 下一阶段计划

- **Phase 3: Claude Code Provider + 多 Provider 轮换**
  - 接入本地 Claude Code 会话与运行态
  - 刘海左右两侧多 AI 并行状态切换
  - 动态任务执行微光环
