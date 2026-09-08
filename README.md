# Dev Notch

**Dev Notch** 是专为 macOS 设计的原生「AI Developer Dynamic Island」桌面应用。它巧妙利用 MacBook 的物理刘海区域（并在无刘海屏幕上自适应为顶部虚拟岛），为开发者提供沉浸、轻量且无打扰的 AI 运行状态、额度用量、实时任务流式光环（Task Pulse）与快捷控制中心。

---

## 📌 当前开发阶段

- **Phase 1：原生刘海窗口底座与三态交互（已完成）**
- **Phase 2：AI Provider 架构与 Codex Provider 真实接入（已完成）**
- **Phase 3：Multi-Provider 统一架构与 OpenCode Go 接入（已完成）**
- **Phase 4：DeepSeek 真实余额接入与 Generic Provider Metrics 架构升级（已完成）**
- **Phase 5：Claude Code Provider 接入与 Live Activity 桥接（已完成）**
- **Phase 6：Google Antigravity Provider + Generic AI Activity + Task Pulse（已完成）**

---

## 🛠 技术栈

- **开发语言**：100% Swift 5.9+ / Swift 6 现代并发规范（Actor 隔离、Sendable 检查）
- **UI 框架**：SwiftUI
- **窗口系统**：AppKit（`NSPanel` + `NSHostingView` + `NSWindowController`）
- **跨进程桥接**：100% Swift 原生编译的独立 CLI 桥接工具（`DevNotchActivityBridge` / `DevNotchClaudeBridge`，无 Node/Python/jq 依赖）
- **构建与测试**：`xcodegen` + `xcodebuild` + `XCTest`
- **目标平台**：macOS 14.0+ (Sonoma / Sequoia)
- **适配架构**：Apple Silicon (arm64) 原生支持
- **设计哲学**：0 第三方运行时框架，纯正 macOS 原生手感，Local-First 安全隐私设计

---

## 🚀 如何 Build & Run & Test

### 编译并启动应用
```bash
./script/build_and_run.sh
```

### 运行完整自动化测试套件
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DevNotch.xcodeproj \
  -scheme DevNotch \
  -destination 'platform=macOS' \
  test
```

---

## ✨ 核心架构与功能

### 1. 通用度量与活动架构 (Generic Metrics & AI Activity)
- **多维度度量体系 (`AIProviderMetric`)**：
  - `.usageWindow`：周期性限额窗口（Codex 5h / Weekly）。
  - `.balance`：高精度货币余额（DeepSeek `¥0.73`，采用 `Decimal` 金融精度）。
  - `.credits`：点数与额度状态。
  - `.context`：模型上下文窗口占用率（`AIContextMetric`）。
  - `.sessionCost`：会话累计开销金额（`AISessionCostMetric`）。
- **通用活动状态模型 (`AIActivityState`)**：
  - 标准状态机：`idle`、`working`、`waitingForApproval`、`completed`、`failed`。
  - 瞬态完成反馈：任务完成时刘海紧凑态短暂展示 `✓ Done` 约 3 秒后自然恢复。
  - 防强退看门狗：会话未正常触发 Stop 退出时，45 秒超时自动降级恢复为 `idle`。

### 2. Task Pulse 任务流式光环
- **克制优雅的原生微光带 (`TaskPulseView`)**：
  - 位于刘海底部曲面边缘的 1.5pt 动态光带，不破坏窗口几何尺寸，不截获鼠标点击。
  - **Working 态**：青蓝微弱渐变呼吸微光（`opacity: 0.35` ~ `0.95`）。
  - **Approval 态**：稳定常亮的橙色警示光。
  - **Completed 态**：绿色完成瞬态高亮（1.2 秒后淡出）。
  - **辅助功能兼容**：严格遵循 macOS `Reduce Motion` 减弱动态效果设置，开启时自动关闭连续动画，改为静态常亮微光。

### 3. 多 AI 厂商真实接入现状

| 提供商 | 认证模式 | 核心度量 / 能力 | 本机验证状态 |
| :--- | :--- | :--- | :--- |
| **OpenAI Codex** | ChatGPT OAuth | 5h 滚动额度 (0%)、Weekly 配额 (84%) | 官方 App-Server 进程与配额全链路已验证 |
| **DeepSeek** | API Key (via OpenCode) | 账户余额 (¥0.73)、充值金/赠金细项 | 官方 API `GET /user/balance` 实时验证通过 |
| **Google Antigravity** | Google Account OAuth | CLI v1.1.27 探测、活动钩子桥接、Task Pulse | 本机 CLI 与配置验证通过；Desktop 未安装；配额接口未公开 |
| **Anthropic Claude Code** | 官方 CLI v2.1.236 | 上下文占用、活动钩子桥接、Task Pulse | 本机未登录认证（认证验证待补齐）；桥接与安全融合已验证 |
| **OpenCode Go** | 本地 CLI v1.18.20 | 多窗口模型自适应 (5h/Weekly/Monthly) | 本机 CLI 探测通过；云端订阅待配置 |

### 4. 统一活动桥接与脱敏安全 (`DevNotchActivityBridge`)
- **白名单元数据清洗 (`ActivityPayloadSanitizer`)**：
  - 仅提取会话 ID、模型、项目名、上下文比例、开销金额、活动状态与时间戳。
  - **严格剔除并丢弃**：Prompt 内容、Response 内容、Tool 输入参数、Shell 命令行内容与源代码。
- **原子无网络 IPC (`ActivityIPCWriter`)**：
  - 通过原子替换写入 `~/Library/Application Support/DevNotch/Activities/{providerID}.json`。
- **非侵入式配置保护**：
  - Claude：安全合并 `~/.claude/settings.json`，保留已有第三方钩子（如 `_otty_grok`）与自定义状态栏。
  - Antigravity：按标准在 `~/.gemini/config/hooks.json` 注册独立命名钩子 `dev-notch-antigravity`，卸载时精准清理自身项。

---

## 🔒 安全与隐私承诺

- **No credential leakage was observed in the implemented tests and log inspection.**
- **AI Activity only processes local session metadata, strictly excluding prompts, responses, tool inputs, and source code content.**
- 应用程序始终坚持 Local-First，无任何远程遥测或私密数据留存。

---

## 🧪 自动化测试套件 (64 个测试全部通过)

内置全面的单元与集成回归测试，包括：
- `TaskPulseTests`：Working/Approval/Completed 状态光环、Reduce Motion 减弱动态效果、多 Provider 并行执行隔离。
- `AntigravityDiscoveryTests` & `AntigravityIntegrationTests` & `AntigravityActivityTests`：CLI/Desktop 探测、版本提取、配置安全融合、载荷脱敏审计、原子 IPC。
- `ClaudeParsingTests` & `ClaudeIntegrationTests` & `ClaudeActivityTests`：安全钩子融合、活动状态机流转、超时看门狗。
- `DeepSeekParsingTests` & `DeepSeekClientTests` & `DeepSeekCredentialTests`：官方余额 API 协议断言。
- `AIProviderManagerTests`：五厂商并行调度、Primary 持久化、容灾回退、超时与异常隔离。
- `AIUsageWindowTests` & `GenericMetricsTests` & `CodexParsingTests` & `OpenCodeParsingTests`。
