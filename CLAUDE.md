# CLAUDE.md

本文件为在此仓库工作的代理提供编码约定和项目上下文。

## 项目

**办它** 是一个 Local First 的 SwiftUI 任务应用，支持 iOS、macOS、iOS Widget 和 macOS 菜单栏应用。用户数据优先以 JSON 文件存储在 iCloud Documents 中；不可用时回退到本地 Documents。SQLite 只用于 FTS 全文搜索索引。

当前应用已经不是旧的宽泛 MVP 规格。以当前代码为准，不要按旧产品说明推断行为。

## 构建

Xcode 工程由 XcodeGen 根据 `project.yml` 生成。

```bash
xcodegen generate
```

构建命令：

```bash
xcodebuild -project 办它.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16' \
  build

xcodebuild -project 办它.xcodeproj \
  -scheme TodoLite-macOS \
  -destination 'platform=macOS' \
  build
```

测试命令：

```bash
xcodebuild -project 办它.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16' \
  test
```

`project.yml` 中的 targets：

- `TodoLite-iOS`：iOS 应用，deployment target 17.0
- `TodoLite-macOS`：macOS 应用，deployment target 14.0
- `TodoLiteWidget`：iOS WidgetKit 扩展
- `TodoLiteTests`：iOS 单元测试

当变更应该写入 `project.yml` 时，不要手动编辑 `办它.xcodeproj/project.pbxproj`。

## 架构

数据流：

```text
View -> TodoStore (@Observable) -> Repository actor -> FileSystemManager actor -> JSON files
```

视图应调用 `TodoStore` API。不要让 feature view 直接读写 JSON 文件。

重要组件：

- `TodoLite/App/TodoLiteApp.swift`：应用入口。创建 `ContentView`，初始化目录，加载全部数据，启动 iCloud 监控，并添加 macOS `MenuBarExtra`。
- `TodoLite/App/ContentView.swift`：平台导航。iOS 使用 `TabView`；macOS 使用 `NavigationSplitView` 和键盘快捷键。
- `TodoLite/Shared/Store/TodoStore.swift`：可观察应用状态和公开 async CRUD 接口。
- `TodoLite/Shared/Repository/*.swift`：任务、项目、标签、今日关注和 LLM 配置的 actor repository。
- `TodoLite/Shared/FileSystem/FileSystemManager.swift`：通过 `NSFileCoordinator` 读写、列出和删除 JSON；创建应用目录；从 iCloud 回退到本地 Documents。
- `TodoLite/Shared/FileSystem/iCloudSyncManager.swift`：使用 `NSMetadataQuery` 监控已下载 JSON 的变化。
- `TodoLite/Shared/Search/SearchIndexer.swift`：Application Support 下的 SQLite FTS5 contentless index。
- `TodoLite/Shared/Parser/TodoParser.swift`：快速录入规则解析器。
- `TodoLite/Shared/LLM/*.swift`：OpenAI-compatible chat service 和任务解析器。
- `TodoLite/Shared/Widget/WidgetDataStore.swift`：把今日关注摘要写入 App Group defaults，供 widget 使用。

## 当前产品形态

主要页面：

- 今日：关注、建议、逾期、即将到来
- 收件箱：`status == .inbox` 的任务
- 看板：三列，`inbox`、`doing`、`done`
- 搜索：基于标题、描述、项目、标签的 SQLite FTS 结果
- 项目：项目 CRUD
- 标签：标签管理
- 已完成：按周分组的完成任务，可选 LLM 周报生成
- 已归档：归档任务
- 设置：字体大小和 LLM 配置

iOS 顶层导航包含今日、收件箱、看板、搜索、设置。macOS 侧边栏还暴露项目、标签、已完成、已归档。

## 模型

`TodoItem` 字段：

- `id`
- `title`
- `description`
- `status`
- `projectId`
- `tagIds`
- `scheduledAt`
- `dueAt`
- `createdAt`
- `updatedAt`
- `completedAt`
- `version`

`TodoStatus` 当前状态：

- `inbox`
- `doing`
- `done`
- `archived`

旧状态解码需要保持兼容：

- `next` -> `doing`
- `waiting` / `blocked` / `someday` -> `doing`
- `cancelled` -> `archived`
- unknown -> `inbox`

除非产品、迁移和测试都明确更新，否则不要增加或删除状态。

默认值：

- 新任务：`status = .inbox`，`version = 1`
- 新项目：emoji `📁`，颜色 `#007AFF`，`isArchived = false`
- 新标签：颜色 `#FF9500`
- LLM 配置：base URL `https://api.openai.com/v1`，model `gpt-4o-mini`

## 今日语义

今日关注不存储在 `TodoItem` 上，而是存储在 `meta/focus_yyyy-mm-dd.json` 中的 `FocusSet`。

`TodoStore` 派生集合：

- `focusTodos`：当前 `FocusSet` 中的 ID，排除已完成和已归档
- `suggestedTodos`：今天到期、未关注，排除已完成和已归档
- `overdueTodos`：今天之前到期、未关注，排除已完成和已归档
- `upcomingTodos`：明天或以后到期、未关注，排除已完成和已归档

保持以下概念分离：

- `scheduledAt`：任务上的计划日期字段
- `dueAt`：当前 Today 建议使用的截止日期字段
- `FocusSet`：显式的今日关注列表

当前 UI 主要使用 `dueAt`；除非已经实现，不要声称存在 scheduled-date 行为。

## 磁盘文件

预期应用数据布局：

```text
TodoLite/
  tasks/task_<id>.json
  projects/project_<id>.json
  tags/tag_<id>.json
  trash/
  archive/
  conflicts/
  meta/focus_yyyy-mm-dd.json
  config/llm_config.json
```

`FileSystemManager` 创建这些目录。`SearchIndexer` 将 `search_index.sqlite` 写入 Application Support，不写入 source-of-truth 目录。

## 持久化规则

- JSON 文件是 source of truth。
- 搜索索引是可丢弃的，可从当前 store 数据重建。
- `TodoRepository.save` 会检查版本，并在抛出 `FileSystemError.conflictDetected` 前写入冲突备份。
- 保存会递增 `version` 并刷新 `updatedAt`。
- 删除任务当前会移除 JSON 文件；归档是把 `status` 改为 `.archived`。
- LLM 不直接写文件。LLM 只返回 draft 或文本；持久化仍通过 store/repository。

## 快速录入和 LLM

规则解析器语法：

- `@project`
- `#tag`
- `^date`

日期由 `DateResolver` 解析，支持 `today`、`tomorrow`、`weekend`、`next week`、weekday 和简单数字日期格式。

通过快速录入创建任务时，可以按名称创建缺失的项目和标签。`CreateTodoView` 在没有解析出 due date 时，默认新任务截止日期为从今天起三个工作日后。

LLM 解析使用 `LLMParser` -> `LLMService.chat`，请求地址为 `baseURL + /chat/completions`。

## Widget 和菜单栏

`WidgetDataStore.sync` 将关注任务数量和前三个关注任务标题写入 `UserDefaults(suiteName: "group.com.donghao.TodoLite")`，并在 WidgetKit 可用时刷新 widget timeline。

macOS 菜单栏应用显示最多五个关注任务标题、新建任务命令、打开应用命令和退出命令。

## UI 规范

- 使用 SwiftUI 和 SF Symbols。
- iOS/macOS 平台专属 API 必须放在 `#if os(iOS)` / `#if os(macOS)` 后面。
- 优先使用现有 shared components：`TaskListView`、`TodoListCard`、`TagChip`、`FlowLayout`、`OptionRow`、`CardButtonStyle`、`EmptyStateView`。
- 使用 `Color+Card.swift` 和 `Color+Hex.swift` 中已有的颜色 helper。
- 语义分区颜色使用 `Color+Card.swift` 中的 `SectionTheme`。它定义了今日、即将到来、收件箱、进行中、已完成、已归档的主题背景色、主题背景上的文本色、主/次页面背景上的文本色和浅背景色。
- 保持应用原生、安静的生产力工具质感。避免营销式页面、重装饰效果或卡通视觉。
- 用户可见文案使用符合本应用语境的中文，除非有明确理由使用其他语言。

## 测试说明

测试位于 `Tests/TodoLiteTests.swift`，覆盖：

- 模型 Codable round trip
- 旧 `TodoStatus` 解码
- `TodoParser`
- `DateResolver`
- `TodoStore` 派生集合

修改模型解码、Today 派生逻辑、parser 行为或 repository 语义时，应更新或新增测试。

## 发布流程

- 版本号仅在 `project.yml` 中管理，禁止手动修改 `Info.plist` 或 `.xcodeproj` 中的版本字段。
- 发布前必须确保 `main` 分支的 GitHub Actions 构建通过（`.github/workflows/build.yml`）。
- 使用语义化版本标签触发发布：`git tag v<major>.<minor>` 并推送。
- 打标签前必须完成以下检查：
  1. `xcodegen generate` 后工程无未同步变更（`git diff --exit-code 办它.xcodeproj/`）
  2. iOS 和 macOS 双平台 `xcodebuild` 构建通过
  3. 测试通过（`xcodebuild ... test`）

## 代理工作流

- 修改文档或行为前，先检查当前代码。
- 尊重用户未提交的改动。不要回滚无关文件。
- 除非用户要求，不要自动 commit。
- 代码变更后，在声称完成前运行最相关的 build 或 test 命令。仅文档变更时，至少检查变更文件并运行 `git diff --check`。
- 如果修改 `project.yml`，运行 `xcodegen generate`，然后验证生成的工程变更。
- 同步规则：修改 `AGENTS.md` 或 `CLAUDE.md` 中任意一份代理说明时，必须检查另一份文件，并保持两者的项目事实、命令、工作流规则和约定同步。
