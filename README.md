# Dev Notch

**Dev Notch** 是专为 macOS 设计的原生「AI Developer Dynamic Island」桌面应用。它巧妙利用 MacBook 的物理刘海区域（并在无刘海屏幕上自适应为顶部虚拟岛），为开发者提供沉浸、轻量且无打扰的 AI 运行状态、额度用量、实时活动与快捷控制中心。

---

## 📌 当前开发阶段

- **Phase 1：原生刘海窗口底座与三态交互（已完成）**
- **Phase 2：AI Provider 架构与 Codex Provider 真实接入（已完成）**
- **Phase 3：Multi-Provider 统一架构与 OpenCode Go 接入（已完成）**
- **Phase 4：DeepSeek 真实余额接入与 Generic Provider Metrics 架构升级（已完成）**
- **Phase 5：Claude Code Provider 接入与 Live Activity 桥接（已完成）**

---

## 🛠 技术栈

- **开发语言**：100% Swift 5.9+ / Swift 6 现代并发规范（Actor 隔离、Sendable 检查）
- **UI 框架**：SwiftUI
- **窗口系统**：AppKit（`NSPanel` + `NSHostingView` + `NSWindowController`）
- **IPC 桥接**：100% Swift 编译的高性能独立 CLI 桥接器（`DevNotchClaudeBridge`，无 Node/Python/jq 依赖）
- **构建与测试**：`xcodegen` + `xcodebuild` + `XCTest`
- **目标平台**：macOS 14.0+ (Sonoma / Sequoia)
- **适配架构**：Apple Silicon (arm64) 原生支持
- **设计哲学**：0 第三方运行时框架，纯正 macOS 原生手感，Local-First 安全隐私架构

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

### 1. 通用度量架构 (Generic Provider Metrics)
- **全度量泛型枚举 (`AIProviderMetric`)**：
  - `.usageWindow(AIUsageWindow)`：周期性配额（如 Codex 5h、Weekly）。
  - `.balance(AIBalance)`：货币账户余额（使用 `Decimal` 保证金融精度，如 DeepSeek `¥0.73`）。
  - `.credits(AICredits)`：点数与信用余额。
  - `.context(AIContextMetric)`：当前会话 Context Window 占用百分比（如 `43% used`）。
  - `.sessionCost(AISessionCostMetric)`：当前交互会话累计花费金额（如 `$0.42`）。
- **解耦 Compact 展示**：引入 `AICompactMetric`，由各 Provider 自主声明最适合在刘海紧凑态展示的内容，彻底废除数组排序假设，UI 层零硬编码类型判断。

### 2. Multi-Provider 调度与注册表 (Registry)
- **注册式架构**：`AIProviderRegistry` 统一注册 `CodexProvider`、`ClaudeProvider`、`OpenCodeGoProvider`、`DeepSeekProvider`。
- **完全错误隔离**：`AIProviderManager` 采用 `withTaskGroup` 并发拉取刷新，单个 Provider 异常或超时绝不污染其他卡片。
- **Primary Provider 偏好与运行时回退**：
  - 支持用户指定并持久化首选 Primary Provider（UserDefaults 存储）。
  - 运行时健康监测：偏好 Provider 临时不可用时自动回退（Runtime Fallback）到第一个健康 Provider，一旦恢复自动切回，绝不篡改用户偏好。

### 3. Claude Code Provider 与 Live Activity 桥接 (Phase 5)
- **官方 CLI 认证模式自适应**：
  - 自动运行官方 `claude auth status --json`，区分 `claude.ai` 订阅模式（Pro / Max / Team）与 API Key 模式，绝不抓取或存储用户私密 Token。
  - 遵守官方能力现状，Subscription 模式下客观呈现“Subscription usage not exposed externally”，绝不利用不可靠逆向接口伪造配额。
- **100% Swift 轻量级桥接器 (`DevNotchClaudeBridge`)**：
  - 独立原生 Swift CLI 工具，执行耗时 < 5ms。
  - 通过原子写入 `~/Library/Application Support/DevNotch/Claude/session.json` 与主 App 通信。
- **非侵入式设置安全融合 (`ClaudeIntegrationManager`)**：
  - 读取用户现存的 `~/.claude/settings.json` 时完整保留已有配置与第三方钩子（如 `_otty_grok`）。
  - 仅在用户显式开启时注入带有 `_dev_notch: true` 标记的钩子；卸载时仅剔除自身注入项，绝不损坏用户配置。
  - 若用户已有自定义 `statusLine`，严格予以保留，绝不静默覆盖。
- **实时活动状态机 (`AIActivity`)**：
  - 状态流转：`idle` -> `working` -> `waitingForApproval` -> `completed`。
  - 瞬态完成反馈：任务完成时刘海紧凑态短暂展示 `Claude ✓ Done` 约 3 秒后自然恢复。
  - 防强退看门狗：会话强退（如 Ctrl+C / kill -9）导致未触发 Stop 钩子时，45 秒超时自动降级恢复为 `idle`。

### 4. 多 AI 厂商真实接入
- **OpenAI Codex**：官方 `codex app-server --stdio` 管道连接，JSON-RPC 2.0 实时 5h / Weekly 额度。
- **DeepSeek**：官方 API `GET https://api.deepseek.com/user/balance` 实时金额读取与 Decimal 精度展示。
- **OpenCode Go**：CLI 自动探测（v1.18.20），清晰标识 Provider 接入状态。
- **Anthropic Claude Code**：官方 CLI（v2.1.236）认证检测与会话活动桥接。

---

## 🔒 安全与隐私承诺

- **No credential leakage was observed in the implemented tests and log inspection.**
- **Claude Live Activity only processes local session metadata, strictly excluding prompts, responses, and source code content.**
- 应用程序始终坚持 Local-First，无远程遥测上传，无敏感凭据持久化。

---

## 🧪 自动化测试套件 (51 个测试全部通过)

内置全面的单元与集成回归测试，包括：
- `ClaudeParsingTests`：Auth 订阅/API 模式解析、statusLine JSON 解析、Context 比例计算、Session Cost Decimal 转换、未知字段向前兼容、可执行文件定位。
- `ClaudeIntegrationTests`：安全设置融合、已有第三方钩子保留、已有自定义状态栏保留、_dev_notch 唯一清理、畸变 JSON 容错。
- `ClaudeActivityTests`：钩子事件状态映射、45s 超时看门狗、3s 瞬态完成反馈、紧凑态层级优选、原子 IPC 文件读写、无 Prompt/Response 捕获审计。
- `DeepSeekParsingTests` & `DeepSeekClientTests` & `DeepSeekCredentialTests`：官方余额 API 与 MockURLProtocol 状态码验证。
- `AIProviderManagerTests`：四厂商并行调度、Primary 持久化、容灾回退、超时与异常隔离。
- `AIUsageWindowTests` & `GenericMetricsTests` & `CodexParsingTests` & `OpenCodeParsingTests`。
