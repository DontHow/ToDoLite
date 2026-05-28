# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本文档为 Claude Code (claude.ai/code) 提供本仓库的开发指南。

## 项目概述

TodoLite 是一个 Local First 的原生 SwiftUI 待办应用，支持 iOS 和 macOS。数据以独立 JSON 文件形式存储在 iCloud Documents 中（不使用 SwiftData / Core Data）。每个待办、项目和标签都是单独的 JSON 文件。SQLite 仅用于全文搜索索引，不作为事实源。

设计理念为 **"Apple 原生+（增强微设计）"** —— 让应用感觉像 Apple 第一方应用，但带有精品级设计细节。不能显得千篇一律，也不应违背原生平台行为。

## 构建与开发

### 项目生成
本项目使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。`.xcodeproj` 由 `project.yml` 生成，不应手动编辑。

```bash
xcodegen generate
```

### 构建
```bash
# iOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16'

# macOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-macOS -destination 'platform=macOS'
```

### 运行测试
```bash
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16' test

# 运行单个测试类
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TodoLiteTests/TodoLiteTests test
```

### 目标（来自 project.yml）
- `TodoLite-iOS` — iOS 应用（部署目标 17.0）
- `TodoLite-macOS` — macOS 应用（部署目标 14.0）
- `TodoLiteWidget` — iOS 小组件扩展
- `TodoLiteTests` — 单元测试

## 架构

### 数据流（严格）
```
View → TodoStore (Observable) → Repository (actor) → FileSystemManager (actor) → JSON 文件
```
视图禁止直接操作 `FileSystemManager`。所有文件操作必须通过 `TodoStore` 或 Repository 层。

### 核心组件

| 层级 | 文件 | 职责 |
|------|------|------|
| 状态 | `Shared/Store/TodoStore.swift` | `@Observable` 单例。持有 `todos`、`projects`、`tags`。所有 CRUD 为异步操作，Repository 确认成功后更新 store。 |
| 仓库 | `Shared/Repository/TodoRepository.swift`、`ProjectRepository.swift`、`TagRepository.swift` | `actor` 单例。写入前进行版本号冲突检测。 |
| 文件系统 | `Shared/FileSystem/FileSystemManager.swift` | `actor` 单例。使用 `NSFileCoordinator` 读写删。iCloud 不可用时回退到本地 `documentDirectory`。 |
| 同步 | `Shared/FileSystem/iCloudSyncManager.swift` | `NSMetadataQuery` 监听 iCloud 文件变更，按版本号合并到 `TodoStore`。 |
| 搜索 | `Shared/Search/SearchIndexer.swift` | SQLite FTS5 索引。`TodoStore` 在数据变更时调用 `indexer.rebuild/index/remove`。 |
| 解析器 | `Shared/Parser/TodoParser.swift`、`DateResolver.swift` | 基于规则（非 AI）的快速录入解析器。语法：`@项目`、`#标签`、`!优先级`、`^日期`。 |

### 冲突解决
仓库在写入前检查 `version`。如果传入版本不大于已有版本，则将冲突备份写入 `conflicts/` 目录，并抛出 `FileSystemError.conflictDetected`。iCloud 同步按版本号合并（`iCloudSyncManager`）。

### Today 设计

Today 不是任务属性。任务上没有 `isToday` 或 `focusedAt` 字段。

Today 是"当天工作上下文"，单独存储在 `meta/focus_yyyy-mm-dd.json`：

```json
{
  "date": "2026-05-27",
  "taskIds": ["task_001", "task_002"]
}
```

Today 页面分三个区域：

| 区域 | 来源 | 说明 |
|------|------|------|
| **Focus** | `focus_yyyy-mm-dd.json` 中的 taskIds | 用户主动加入 Today 的任务 |
| **Suggested** | `scheduledAt` 为今天 或 `dueAt` 为今天 | 系统建议，不自动进入 Focus |
| **Overdue** | `dueAt` < 今天 | 逾期任务，不污染 Focus |

Focus 排序：优先级（高 > 中 > 低），然后按加入顺序。

**时间字段语义（严格分离）：**
- `scheduledAt` = "我计划什么时候做"（未来安排）
- `dueAt` = "最晚什么时候完成"（截止约束）
- **Today Focus** = "今天主动关注什么"（当日工作上下文）

三者彻底分离，不要混为一谈。

### 状态映射（Codable 迁移）
废弃状态在 JSON 解码时重映射：
- `next` → `doing`
- `blocked` → `waiting`
- `someday` → `waiting`
- `cancelled` → `archived`

### 磁盘文件结构
```
iCloud Drive/TodoLite/
  tasks/task_<id>.json
  projects/project_<id>.json
  tags/tag_<id>.json
  trash/
  archive/
  conflicts/
  meta/
    focus_yyyy-mm-dd.json
```

## 测试规范

测试位于 `Tests/TodoLiteTests.swift`。使用 `@testable import TodoLite`，测试内容：
- Model Codable 编解码
- Parser 边界情况（空输入、emoji、多空格、大小写不敏感）
- `DateResolver` 边界情况（周末、跨年、从今天算 weekday）
- `TodoStore` 派生集合（`focusTodos`、`suggestedTodos`、`overdueTodos`、`activeTodos`、`inboxTodos`）及排序
- 旧版 JSON 字符串的状态 Codable 迁移

## UI 结构

- **iOS**：`TabView`，标签页：Today、Inbox、Board、Search、Settings
- **macOS**：`NavigationSplitView`，Sidebar → 详情。包含 `MenuBarExtra`。快捷键：⌘1 Today、⌘2 Inbox、⌘3 Board、⌘K Search

Sidebar / Tab 视图列表：Today、Inbox、Overdue、Upcoming、Board、Projects、Tags、Done、Archive

### 视觉规范

**字体与层级：** 使用标准 SF Pro 字体，通过极端布局层级建立对比。分区标题优先使用 `.font(.system(.title3, design: .rounded, weight: .bold))`。任务标题使用 `.body` 或 `.callout` 配合 `.semibold` 字重。元数据使用 `Color(.secondaryLabel)`，保持画布干净。

**布局与间距：** 标准内边距 iOS `16pt`，macOS `12pt`。使用显式视觉容器代替原始列表，需要视觉风格时用自定义语义卡片分组，而非标准 `Form` 或 `List` 背景。不使用厚重阴影，暗色模式分隔使用微妙边框：`.border(Color(.separator).opacity(0.5), width: 0.5)`。

**微交互：** 按钮按下和单元格选中必须带有响应式缩放：`.scaleEffect(isPressed ? 0.98 : 1.0)`。macOS 悬停效果（`.onHover`）默认隐藏可操作项（删除/编辑图标），悬停时显现。持久栏使用系统材质：`.background(.ultraThinMaterial)`。

## 重要原则

1. **文件系统是事实源。** 禁止将 SQLite 或内存作为权威来源。
2. **UI 禁止直接操作文件。** 始终通过 `TodoStore` → Repository。
3. **同步层与业务逻辑解耦。** `iCloudSyncManager` 只更新 `TodoStore`，不触发副作用。
4. **写入路径禁止 AI。** Quick Entry 使用 `TodoParser`（基于规则），不是 LLM。
5. **防数据丢失高于一切。** 所有写入为原子操作（`Data.write(options: .atomic)`），保留冲突备份，每次保存递增版本号。

## 模型默认值

新建模型时应遵循以下默认值：

| 模型 | 字段 | 默认值 |
|------|------|--------|
| `TodoItem` | `status` | `.inbox` |
| `TodoItem` | `priority` | `.medium` |
| `TodoItem` | `version` | `1` |
| `Project` | `emoji` | `"📁"` |
| `Project` | `colorHex` | `"#007AFF"` |
| `TagItem` | `colorHex` | `"#FF9500"` |

## MVP 开发阶段

项目按六阶段递进开发，当前进度决定新增功能应落在哪个层级：

1. **核心数据层** — Models / Repository / FileSystem / JSON Store
2. **本地 CRUD** — Task List / Task Detail / Create/Edit/Delete
3. **iCloud** — iCloud Container / NSMetadataQuery / 文件监听
4. **Today + Board** — Today / Board / Drag & Drop
5. **Parser + Search** — Quick Entry / SQLite FTS
6. **体验层** — 快捷键 / MenuBar / Widget / 动画

新增功能时，先判断属于哪个阶段。若依赖的阶段尚未完成，应优先补齐依赖而非跳跃实现。

## 工作流规范

- **每次改动完成后自动提交。** 单一代码改动完成并验证编译通过后，应直接执行 `git add` 和 `git commit`，无需等待用户额外确认。
- 每次改动完成后自动编译构建 debug macos，然后重新打开
- **多平台兼容性检查。** 使用 `Color(uiColor:)` 或 `Color(nsColor:)` 等 UIKit/AppKit 专属 API 时，必须用 `#if os(iOS)` / `#else` 包裹，确保 iOS 和 macOS 双目标均能编译。
- **`xcodegen generate` 后需重新打开 Xcode。** 修改 `project.yml` 后，先生成项目再重新加载 Xcode，`.pbxproj` 不应手动编辑。
- **多平台分离。** 清晰分离 iOS 专用布局（如带底部 TabBar 的 `NavigationStack`）与 macOS 专用布局（如带侧边栏和顶部工具栏的 `NavigationSplitView`）。恰当使用 `#if os(iOS)` 和 `#if os(macOS)`，或隔离平台视图。
- **仅使用 SF Symbols。** 所有图标使用原生 SF Symbols，尽可能应用层级渲染变体 `.symbolRenderingMode(.hierarchical)`。
- **禁止第三方依赖。** 使用纯 SwiftUI。编写模块化、高度可复用的子视图（如 `TaskRow`、`CategoryCard`）。确保代码在 Swift 6 严格并发安全下完全编译。
- **禁止占位符。** 提供功能完整的 SwiftUI 视图，逻辑清晰。不要用 `// ... implement later` 等注释截断代码。
- 当用户说“发布”时，自动提高版本号，然后打 tag，将编译好的macOS应用安装
