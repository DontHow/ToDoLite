# CLAUDE.md

本文档为 Claude Code (claude.ai/code) 提供本仓库的开发指南。

## 项目概述

TodoLite 是一个 Local First 的原生 SwiftUI 待办应用，支持 iOS 和 macOS。数据以独立 JSON 文件形式存储在 iCloud Documents 中（不使用 SwiftData / Core Data）。每个待办、项目和标签都是单独的 JSON 文件。SQLite 仅用于全文搜索索引，不作为事实源。

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

### Today 逻辑
`TodoStore.isToday(_:now:)` 决定成员资格。待办出现在 Today 的条件：
- 非 done/archived，且
- `isPinnedToday == true`，或 `scheduledAt` 为今天，或 `dueAt` <= now

Today 排序：置顶优先，然后按优先级（高 > 中 > 低），最后按 createdAt 升序。

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
```

## 测试规范

测试位于 `Tests/TodoLiteTests.swift`。使用 `@testable import TodoLite`，测试内容：
- Model Codable 编解码
- Parser 边界情况（空输入、emoji、多空格、大小写不敏感）
- `DateResolver` 边界情况（周末、跨年、从今天算 weekday）
- `TodoStore` 派生集合（`todayTodos`、`activeTodos`、`inboxTodos`）及排序
- 旧版 JSON 字符串的状态 Codable 迁移

## UI 结构

- **iOS**：`TabView`，标签页：Today、Inbox、Board、Search、Settings
- **macOS**：`NavigationSplitView`，Sidebar → 详情。包含 `MenuBarExtra`。快捷键：⌘1 Today、⌘2 Inbox、⌘3 Board、⌘K Search

## 重要原则

1. **文件系统是事实源。** 禁止将 SQLite 或内存作为权威来源。
2. **UI 禁止直接操作文件。** 始终通过 `TodoStore` → Repository。
3. **同步层与业务逻辑解耦。** `iCloudSyncManager` 只更新 `TodoStore`，不触发副作用。
4. **写入路径禁止 AI。** Quick Entry 使用 `TodoParser`（基于规则），不是 LLM。
5. **防数据丢失高于一切。** 所有写入为原子操作（`Data.write(options: .atomic)`），保留冲突备份，每次保存递增版本号。

## 工作流规范

- **每次改动完成后自动提交。** 单一代码改动完成并验证编译通过后，应直接执行 `git add` 和 `git commit`，无需等待用户额外确认。
