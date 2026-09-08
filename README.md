# Dev Notch

**Dev Notch** 是专为 macOS 设计的原生「AI Developer Dynamic Island」桌面应用。它巧妙利用 MacBook 的物理刘海区域（并在无刘海屏幕上自适应为顶部虚拟岛），为开发者提供沉浸、轻量且无打扰的 AI 运行状态、额度用量与快捷控制中心。

---

## 📌 当前开发阶段

- **Phase 1：原生刘海窗口底座与三态交互（已完成）**
- **Phase 2：AI Provider 架构与 Codex Provider 真实接入（已完成）**
- **Phase 3：Multi-Provider 统一架构与 OpenCode Go 接入（已完成）**
- **Phase 4：DeepSeek 真实余额接入与 Generic Provider Metrics 架构升级（已完成）**

---

## 🛠 技术栈

- **开发语言**：100% Swift 5.9+ / Swift 6 现代并发规范（Actor 隔离、Sendable 检查）
- **UI 框架**：SwiftUI
- **窗口系统**：AppKit（`NSPanel` + `NSHostingView` + `NSWindowController`）
- **网络与通信**：原生 `URLSession` + `Process` 进程管道通信（无第三方 HTTP 依赖）
- **构建与测试**：`xcodegen` + `xcodebuild` + `XCTest`
- **目标平台**：macOS 14.0+ (Sonoma / Sequoia)
- **适配架构**：Apple Silicon (arm64) 原生支持
- **设计哲学**：0 第三方运行时框架，0 Node.js/Electron，纯正 macOS 原生手感，Local-First 安全设计

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
- **摆脱纯百分比假设**：引入 `AIProviderMetric` 统一泛型枚举：
  - `.usageWindow(AIUsageWindow)`：周期性限额窗口（如 5 Hour, Weekly, Monthly）。
  - `.balance(AIBalance)`：货币账户余额（使用 `Decimal` 保证金融精度，避免浮点误差，格式化为 `¥0.73` 或 `$12.43`）。
  - `.credits(AICredits)`：点数与额度状态。
- **解耦 Compact 展示**：引入 `AICompactMetric`，由各 Provider 依据自身商业与使用模型声明最适合在刘海紧凑态展示的内容（如 Codex 展示 `0% 5h`，DeepSeek 展示 `¥0.73`），彻底废除 `windows.first` 排序假设，UI 层零硬编码类型判断。

### 2. Multi-Provider 调度与注册表 (Registry)
- **注册式架构**：`AIProviderRegistry` 统一注册与管理所有 Provider（当前支持 `CodexProvider`、`OpenCodeGoProvider`、`DeepSeekProvider`）。
- **完全错误隔离**：`AIProviderManager` 采用 `withTaskGroup` 并发拉取刷新，单个 Provider 异常或超时绝不污染其他正常卡片。
- **Primary Provider 偏好与运行时回退**：
  - 支持用户指定并持久化首选 Primary Provider（UserDefaults 存储）。
  - 当偏好 Provider 临时不可用时，系统自动临时回退（Runtime Fallback）到第一个健康就绪的 Provider，一旦恢复自动切回，绝不篡改用户持久化偏好。

### 3. 多 AI 厂商真实接入
- **OpenAI Codex Provider**：
  - 进程级官方 `codex app-server --stdio` 管道连接，JSON-RPC 2.0 异步双向通信。
  - 实时读取真实 5h 与 Weekly 额度。
- **DeepSeek Provider**：
  - 接入官方 API：`GET https://api.deepseek.com/user/balance`。
  - 安全读取本机已有凭据（环境或 OpenCode `auth.json` 内存短暂使用），绝不持久化、绝不写入日志。
  - 声明独立的低频刷新策略（`interval(600)`，10 分钟），避免无效 API 请求。
  - 真实展示货币余额（如 `¥0.73`）、可用性状态、充值金与赠金细项。
- **OpenCode Go Provider**：
  - 自动发现本地 OpenCode CLI（v1.18.20）。
  - 状态精准区分已接入（Provider Integrated）与实名订阅待配置，绝不使用虚假数据冒充。

### 4. 极致原生刘海视觉
- **Compact**：仅呈现当前 Primary Provider 的状态与核心指标。
- **Hovered**：展示主提供商名、副标题指标、就绪灯与交互指示。
- **Expanded**：420x320 舒适尺寸，内嵌 `ScrollView` 呈现完整的各厂商独立卡片，包含设为 Primary（`★`）操作与单项实时刷新。

---

## 🧪 自动化测试套件 (37 个测试全部通过)

内置全面的单元与集成回归测试，包括：
- `AIProviderManagerTests`：双就绪、单故障隔离、首选持久化、运行时故障回退。
- `DeepSeekParsingTests`：CNY/USD 货币解析、`Decimal` 精度保证、可用性标记与未知字段前向兼容。
- `DeepSeekClientTests`：基于 MockURLProtocol 的 200/401/402/429/500/Malformed 网络响应断言。
- `DeepSeekCredentialTests`：凭据多源定位与不存在安全兜底。
- `GenericMetricsTests`：Balance/Usage/Credits 组合测试与严重等级颜色映射。
- `CodexParsingTests` & `OpenCodeParsingTests`：多窗口报文与异常容灾测试。

---

## 🔮 下一阶段计划

- **Phase 5: Claude Code Provider 接入与多 Provider 并行调度**
- **任务执行态呼吸光环（Task Pulse）**
