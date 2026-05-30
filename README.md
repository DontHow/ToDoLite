# 办他 (TodoLite)

Local First 的原生 SwiftUI 待办应用，支持 iOS 和 macOS。数据以独立 JSON 文件存储于 iCloud Documents，每个待办、项目、标签均为单独文件。

## 功能

- **今日工作上下文** — 手动聚焦今日任务，配合系统建议、逾期提醒、未来截止，四区清晰分离
- **看板视图** — inbox / doing / done 三列，支持拖拽变更状态，可切换分组方式
- **快速录入** — 支持 `@项目`、`#标签`、`^日期` 规则解析，可选 AI 自然语言解析
- **全文搜索** — SQLite FTS5 索引，跨任务标题、描述、项目、标签搜索
- **iCloud 同步** — 基于文件版本号的自动冲突检测与合并
- **iOS 小组件** — Today 聚焦任务一览
- **macOS MenuBar** — 快捷访问与操作

## 技术栈

- **Swift 5.9** + SwiftUI
- **数据层**: 独立 JSON 文件（事实源）+ SQLite FTS5（仅索引）
- **并发**: `actor` 隔离 Repository / FileSystemManager
- **状态**: `@Observable` TodoStore 单例
- **同步**: `NSFileCoordinator` + `NSMetadataQuery`
- **AI 解析**: OpenAI 兼容 API（可选，默认关闭）

## 构建

需要 Xcode 15+。

```bash
# 生成 Xcode 项目（使用 XcodeGen）
xcodegen generate

# iOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16'

# macOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-macOS -destination 'platform=macOS'
```

## 架构

```
View → TodoStore (@Observable) → Repository (actor) → FileSystemManager (actor) → JSON
                                          ↓
                                    SearchIndexer (SQLite FTS5)
```

| 层级 | 说明 |
|------|------|
| `TodoStore` | 唯一状态源，所有视图通过它读写数据 |
| `Repository` | actor 隔离，版本号冲突检测，冲突文件备份到 `conflicts/` |
| `FileSystemManager` | `NSFileCoordinator` 原子写入，iCloud 不可用时回退本地 |
| `iCloudSyncManager` | 监听 iCloud 文件变更，按版本号合并到 TodoStore |
| `TodoParser` / `LLMParser` | 规则解析器（默认）与可选 AI 解析器 |

## 状态

| 状态 | 说明 |
|------|------|
| `inbox` | 新任务默认入口 |
| `doing` | 进行中（原 waiting / blocked / someday 已合并迁移至此） |
| `done` | 已完成 |
| `archived` | 已归档（原 cancelled 迁移至此） |

## 目录结构

```
TodoLite/
  App/              # TodoLiteApp, ContentView, Sidebar, MenuBarView
  Features/         # Today, Inbox, Board, Projects, Search, Settings
  Shared/
    Models/         # TodoItem, Project, TagItem, FocusSet, LLMConfig
    Store/          # TodoStore
    Repository/     # Todo/Project/Tag/Focus/LLMConfig Repository
    FileSystem/     # FileSystemManager, iCloudSyncManager
    Parser/         # TodoParser, DateResolver, TodoDraft
    LLM/            # LLMService, LLMParser
    Search/         # SearchIndexer
    Components/     # TaskListView, TodoListCard, TagChip, FlowLayout
    Extensions/     # Color+Card, Color+Hex
    Utils/          # EmptyStateView
    Widget/         # WidgetDataStore
  Tests/            # 单元测试
TodoLiteWidget/     # iOS 小组件
```

## 开发指南

详见 [CLAUDE.md](CLAUDE.md)。

## 许可证

MIT
