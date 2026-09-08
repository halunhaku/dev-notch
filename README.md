# Dev Notch

**Dev Notch** 是专为 macOS 设计的原生「AI Developer Dynamic Island」桌面应用。它巧妙利用 MacBook 的物理刘海区域（并在无刘海屏幕上自适应为顶部虚拟岛），为开发者提供沉浸、轻量且无打扰的 AI 运行状态、任务提醒与快捷控制中心。

---

## 📌 当前开发阶段

**Phase 1：原生刘海窗口底座与三态交互（已完成）**

当前阶段专注于构建轻量、稳定、高性能的 macOS 原生刘海交互外壳，不引入复杂的业务逻辑与外部依赖。

---

## 🛠 技术栈

- **开发语言**：100% Swift 5.9+ / Swift 6 现代并发规范
- **UI 框架**：SwiftUI
- **窗口系统**：AppKit（`NSPanel` + `NSHostingView` + `NSWindowController`）
- **构建工具**：`xcodegen` + `xcodebuild`
- **目标平台**：macOS 14.0+ (Sonoma / Sequoia)
- **适配架构**：Apple Silicon (arm64) 原生支持
- **设计哲学**：0 第三方运行时框架，0 Node.js/Electron，纯正 macOS 原生手感

---

## 🚀 如何 Build & Run

项目提供了标准统一的构建与启动脚本：

```bash
./script/build_and_run.sh
```

该脚本会自动执行：
1. 安全停止当前正在运行的 DevNotch 实例
2. 根据 `project.yml` 维护最新的 `.xcodeproj` 工程
3. 使用 `xcodebuild` 编译 Debug 版本
4. 启动最新生成的 `DevNotch.app`

同时已配置 `.codex/environments/environment.toml`，在 Codex 环境下可通过 Run 动作一键触发该脚本。

---

##  当前已实现功能

1. **可编译、独立签名的 macOS 原生 App**：包含完整的 `DevNotch.xcodeproj`，可随时在 Xcode 中打开。
2. **多显示器与安全区域检测**：通过 `ScreenManager` 与 `NotchGeometry` 精确读取 `NSScreen.safeAreaInsets`、`auxiliaryTopLeftArea` 与 `auxiliaryTopRightArea`。
3. **真实刘海尺寸匹配与外接显示器自适应**：
   - 在 MacBook 刘海屏上：精准贴合物理刘海宽度与高度。
   - 在无刘海外接显示器上：自适应生成顶部居中的虚拟 Dynamic Island。
4. **非激活式顶级悬浮窗口**：
   - 基于 `.statusBar` 窗口层级，覆盖普通应用但绝不抢夺键盘焦点（`canBecomeKey = false`）。
   - 无 macOS 普通标题栏，禁止随意拖动。
   - 跨虚拟桌面（Spaces）常驻与全屏辅助显示（`fullScreenAuxiliary`）。
5. **流畅三态交互模型（NotchState）**：
   - `compact`：默认紧凑贴合刘海，融入硬件黑色边框。
   - `hovered`：鼠标移入时平滑展开，提供视觉预览与反馈。
   - `expanded`：点击后展开展示核心信息（Dev Notch 标题与 AI Status Center 面板）。
6. **自然的流体动画与自动收起机制**：
   - 采用原生 Spring 弹簧动画曲线。
   - 鼠标移出自动防抖收缩。
   - 展开状态下点击外部区域（Outside Click）自动折叠回 `compact`。

---

## 🔮 下一阶段计划

- **Codex Provider + AI Provider architecture**
  - 抽象统一的 AI 工具运行态接入协议
  - 接入本地 Codex / CLI 会话感知与状态透传
  - 任务执行进度环与状态流转提示
