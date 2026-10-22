# AGENTS.md

本文件为在此仓库工作的代理提供编码约定和项目上下文。

## 项目

**办他 / TodoLite** 是一个 Local First 的 SwiftUI 任务应用，支持 iOS、macOS、iOS Widget 和 macOS 菜单栏应用。用户数据优先以 JSON 文件存储在 iCloud Documents 中；不可用时回退到本地 Documents。SQLite 只用于 FTS 全文搜索索引。

当前应用已经不是旧的宽泛 MVP 规格。以当前代码为准，不要按旧产品说明推断行为。

## 构建

Xcode 工程由 XcodeGen 2.43.0 根据 `project.yml` 生成。CI 固定使用官方 2.43.0 二进制并核验 SHA-256；升级生成器时需同步更新 CI 和生成工程，避免工程格式随工具版本漂移。

```bash
xcodegen generate
```

构建命令：

```bash
xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16' \
  build

xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-macOS \
  -destination 'platform=macOS' \
  build
```

测试命令：

```bash
xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16' \
  test
```

`project.yml` 中的 targets：

- `TodoLite-iOS`：iOS 应用，deployment target 17.0
- `TodoLite-macOS`：macOS 应用，deployment target 14.0
- `TodoLiteWidget`：iOS WidgetKit 扩展
- `TodoLiteTests`：iOS 单元测试

当变更应该写入 `project.yml` 时，不要手动编辑 `TodoLite.xcodeproj/project.pbxproj`。

## 架构

数据流：

```text
View -> TodoStore (@Observable) -> Repository actor -> FileSystemManager actor -> JSON files
```

视图应调用 `TodoStore` API。不要让 feature view 直接读写 JSON 文件。

重要组件：

- `TodoLite/App/TodoLiteApp.swift`：应用入口。iOS 创建 `WindowGroup`，macOS 创建可重新打开的唯一主窗口并添加 `MenuBarExtra` 和新建任务命令。`ContentView` 调用 Store 初始化目录/数据，成功后启动 iCloud 监控。
- `TodoLite/App/ContentView.swift`：平台导航。iOS 使用 `TabView`；macOS 使用 `NavigationSplitView` 和键盘快捷键。
- `TodoLite/Shared/Store/TodoStore.swift`：可观察应用状态和公开 async CRUD 接口。
- `TodoLite/Shared/Repository/*.swift`：任务、项目、标签、今日关注和 LLM 配置的 actor repository。
- `TodoLite/Shared/FileSystem/FileSystemManager.swift`：通过 `NSFileCoordinator` 读写、列出和删除 JSON；创建应用目录；从 iCloud 回退到本地 Documents。
- `TodoLite/Shared/FileSystem/iCloudSyncManager.swift`：使用 `NSMetadataQuery` 监控已下载 JSON 的变化。
- `TodoLite/Shared/Search/SearchIndexer.swift`：Application Support 下的 SQLite FTS5 index。
- `TodoLite/Shared/Parser/TodoParser.swift`：详细输入表单使用的任务文本规则解析器。
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
- 设置：跟随系统字体或自定义大小、LLM 配置；iOS 还提供项目、标签、已完成和归档入口。

iOS 顶层导航包含今日、收件箱、看板、搜索、设置，组织和历史页面从设置进入。macOS 侧边栏还暴露项目、标签、已完成、已归档。窄窗口和辅助功能大字号下看板采用状态选择器加单列，宽窗口保留三列。

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
- 表单通过 `TodoStore.saveDraft` → `DraftRepository` 保存，保留草稿任务 ID，先验证任务再创建缺失元数据。解析产生的同名元数据通过规范化名称的摘要 ID 和 `insertOrRead` 复用；已有元数据按名称优先复用，摘要 ID 被改名记录占用时使用后缀。
- 跨 JSON 文件保存不提供事务保证。元数据写入后任务失败时，通过 `DraftSaveError` 明确报告保留项并同步 Store；不可盲目删除可能被其他任务引用的元数据。同一新建草稿的完全相同重试返回原任务；后续编辑或不同内容须冲突并备份。
- `TodoRepository.create` 只创建不存在的任务；`save` 只更新存在且版本完全匹配的任务。读取、校验和写入在同一次文件协调中完成；版本冲突或未解决的 iCloud 文件版本冲突会在备份此次编辑后抛出 `FileSystemError.conflictDetected`。
- 项目和标签使用 `create` 新建、`save(_:replacing:)` 更新；更新必须在同一次文件协调中与编辑时的原始完整快照比较。已删除项不可由旧编辑器重建，冲突编辑备份到 `conflicts`。
- 今日关注的日常增删调用 `FocusRepository.setFocused`，在文件协调中基于当前磁盘列表修改单个 ID，不覆盖旧内存快照；操作按执行时的今天选文件，旧日关注保持不变。读取时必须验证文件中的日期与文件名对应。
- 保存会递增 `version` 并刷新 `updatedAt`。所有任务保存入口统一归一化完成时间：`done` 补齐 `completedAt`，`inbox` / `doing` 清除它，`archived` 保留已有完成历史。
- 文件不存在、读取失败和 JSON 损坏必须区分；不得用默认值或跳过文件掩盖读取失败。启动加载失败时保留原有内存快照，显示错误和重试入口。
- 本地回退数据迁回 iCloud 时按文件合并：缺失项复制，同名异内容保留云端并备份本地；`meta/migration_<digest>.json` 记录已处理内容，供中断续传并防止已删除任务被重复导入。未下载的文件或迁移回执必须先下载，不得视为缺失。旧本地配置的密钥必须先迁入 Keychain，再迁移不含密钥的配置。
- 本地 CRUD、草稿保存结果和 iCloud 的任务/项目/标签通知统一通过 `TodoStore.refreshRecordFromDisk` 重新读取磁盘；每条记录的读取序号阻止旧结果晚到覆盖新状态。删除通知也重新读取，避免原子替换或恢复后的记录被误移除。写入成功后的刷新失败只提示错误，不伪装成写入失败。全量加载遇到增量刷新或关注/配置变化时最多重试三次，不能覆盖期间已发布的状态。
- iCloud 事件仅处理当前应用目录下的已知文件。同版本任务内容不同时，先备份本机内容，再应用当前磁盘版本并提示用户；完整冲突合并仍需单独处理。
- LLM API Key 仅存于本机 Keychain，不随 JSON 或 iCloud Documents 同步。旧 JSON 中的明文密钥在成功写入 Keychain 后清理；Keychain 不可用时保留旧文件供重试。
- 删除任务先把 `DeletedTodo`（任务快照与删除时间）写入 `trash/deleted_<id>_<version>.json`，成功后才移除原 JSON；两份文件使用一次双目标写协调，禁止嵌套单文件写协调。回收站恢复只新增不存在的任务，并递增版本阻止旧编辑器覆盖。归档仍是把 `status` 改为 `.archived`。
- `RecoveryRepository` 导出版本化 JSON 备份，包含任务、项目、标签、历史关注、回收站，以及任务/项目/标签的冲突副本，不包含 LLM 配置、API Key 和搜索索引。导入必须先完整验证格式、唯一性和安全 ID，再逐条仅新增缺失文件；已有文件（含损坏文件）不覆盖，未下载文件先下载，中断可重试。设置的“回收站与备份”通过 Store 访问这些能力。导出、文件读取和直接导入共用 50 MB 上限；备份使用一批 `NSFileAccessIntent` 同时协调读取已知文件，读取后核对文件集合，集合变化最多重试三次。导出还必须验证文件名与记录 ID/日期匹配。该快照针对本机当前已下载数据，不代表其他设备尚未同步的内容。
- 备份导出格式为 v2，继续支持导入不含冲突字段的 v1。`ConflictRecord` 仅接受与模型 ID 对应且安全的 `task_` / `project_` / `tag_` 冲突文件名；配置等其他冲突文件不展示、不导出，保留原目录内容。
- 设置中的冲突比较页可查看当前记录与副本，并通过 Store → `ConflictRepository` 恢复为独立任务/项目/标签。原记录和冲突文件不删除、不覆盖。恢复前重新读取冲突文件，与已查看快照不符时拒绝恢复；副本 ID 由文件名与内容摘要决定，重复恢复复用已有副本且保留其后续编辑。任务副本删除后再次恢复时，版本必须高于同 ID 的回收站历史，阻止旧编辑器覆盖；恢复项目/标签不改变任务关联。
- 云端占位文件在列表中映射为逻辑文件名，避免加载和导出遗漏未下载的数据。
- LLM 不直接写文件。LLM 只返回 draft 或文本；持久化仍通过 store/repository。

## 任务录入和 LLM

`CreateTodoView` 当前只提供一套详细输入表单，不再提供独立的快速输入模式。标题中的规则语法会在短暂输入停顿后自动解析；核心信息区保留显式的“AI 解析”操作。解析结果会回填标题、描述、项目、标签和截止日期，用户可以继续手动调整。AI 解析期间可取消；若表单在请求期间变化，旧响应不得覆盖新内容。规则解析产生的缺失项目或标签只在保存任务时创建。新任务默认截止日期为从今天起三个工作日后。保存、归档和删除共用操作中的互斥状态，持久化期间禁用表单修改与关闭。

规则解析器语法：

- `@project`
- `#tag`
- `^date`

规则仅识别输入开头或空白后的标记，保留邮箱、URL 和普通文本中的符号；无效日期留在标题中。`^next week` 作为完整短语处理，重复标签去重。仅含规则的输入解析后标题为空，不得保存空标题。

日期由 `DateResolver` 解析，支持 `today`、`tomorrow`、`weekend`、`next week`、weekday 和简单数字日期格式，另支持今天、明天、昨天、周末、一周后。无年份数字日期包含今天，并查找下一个有效日期（包括闰年），禁止自动归一化无效日历日期。

LLM 任务解析使用 `LLMParser` -> `LLMService.chat`，请求地址为 `baseURL + /chat/completions`。提示词明确提供当前本地日期和时区。

完成历史按周一至下周一的半开区间分组，使用周起始日期作为稳定 ID。周报先展示可编辑的发送内容，仅点击“发送并生成周报”才调用模型服务。macOS 本机 AI 会话来源默认不选；只有选择来源后才在后台读取该周的可识别记录，支持取消，不读取日期不明的消息。Claude/Codex/Cursor 均按消息时间使用相同区间筛选；测试必须注入临时目录，不读取真实会话。

## Widget 和菜单栏

`WidgetDataStore.sync` 将关注日期、任务数量和按 FocusSet 顺序排列的前三个任务 ID/标题写入 `UserDefaults(suiteName: "group.com.donghao.TodoLite")`。主应用与 Widget 共用 `WidgetSnapshot.swift`，仅摘要变化时刷新 timeline。Widget 在午夜切换到空快照；昨日或无日期的旧快照不得作为今日数据展示。iOS 应用通过 `project.yml` 嵌入 Widget，双方 App Group 必须一致。

搜索索引对汉字逐字索引并以连续短语匹配，支持中文中间词和单字查询；拉丁文本保留前缀搜索。索引更新/重建使用事务，索引完成后通过 Store 的 revision 通知搜索页刷新；搜索页需区分索引错误和无结果。

macOS 菜单栏应用显示最多五个关注任务标题、新建任务命令、打开应用命令和退出命令。“新建任务”和全局 ⌘N 均打开或聚焦主窗口并显示创建表单。

## UI 规范

- 使用 SwiftUI 和 SF Symbols。
- iOS/macOS 平台专属 API 必须放在 `#if os(iOS)` / `#if os(macOS)` 后面。
- 优先使用现有 shared components：`TaskListView`、`TodoListCard`、`TagChip`、`FlowLayout`、`OptionRow`、`CardButtonStyle`、`EmptyStateView`。
- 使用 `Color+Card.swift` 和 `Color+Hex.swift` 中已有的颜色 helper。
- 语义分区颜色使用 `Color+Card.swift` 中的 `SectionTheme`。它定义了今日、即将到来、收件箱、进行中、已完成、已归档的主题背景色、主题背景上的文本色、主/次页面背景上的文本色和浅背景色。
- 保持应用原生、安静的生产力工具质感。避免营销式页面、重装饰效果或卡通视觉。
- 用户可见文案使用符合本应用语境的中文，除非有明确理由使用其他语言。

## 测试说明

测试位于 `Tests/TodoLiteTests.swift`、`Tests/RecoveryTests.swift`、`Tests/ConsistencyTests.swift`、`Tests/DraftTests.swift`、`Tests/BackupAndMergeTests.swift` 和 `Tests/ConflictTests.swift`，覆盖：

- 模型 Codable round trip
- 旧 `TodoStatus` 解码
- `TodoParser`
- `DateResolver`
- `TodoStore` 派生集合
- 临时独立目录中的任务并发保存、版本冲突、损坏文件保护和加载失败重试
- Store 状态转换和完成时间持久化
- Keychain 密钥读写、旧配置迁移和迁移失败保护
- 中文中间词、单字、混合语言搜索及索引更新/删除
- 本地与云端文件合并、中断续传、迁移回执和占位文件保护
- 同版本同步冲突备份、iCloud 事件目录边界
- Widget 关注顺序、同名任务、旧快照、跨日过期和夏令时
- 规则边界、无效日期保留、完整日期短语、当天数字日期与闰日
- LLM 日期/时区上下文、完成历史跨年分组、周报材料范围
- 临时 Claude/Codex/Cursor 会话的来源选择与消息时间筛选
- 关注列表跨独立文件系统 actor 并发增删、跨日操作、损坏文件保护，以及项目/标签旧编辑、并发保存和重复创建保护
- 草稿 ID 保留与幂等重试、旧任务前置校验、跨 actor 同名元数据复用、不可写目录导致的部分保存恢复、改名后的名称复用
- 备份编码/导入大小边界、稀疏超大文件拒绝、文件名错配、关联双文件并发快照、重复同步通知、过期删除通知、加载与新建交错、刷新失败保留界面快照
- 任务/项目/标签冲突副本恢复、重复恢复保留编辑、删除后恢复版本保护、过期比较快照拒绝、备份 v1/v2 兼容、冲突路径与类型校验、配置密钥排除
- 回收站恢复、写入失败保留源任务、旧编辑器冲突、备份往返、恶意 ID 拒绝、已有/损坏文件保护、占位文件与中断重试

修改模型解码、Today 派生逻辑、parser 行为或 repository 语义时，应更新或新增测试。

## 发布流程

- 版本号仅在 `project.yml` 中管理，禁止手动修改 `Info.plist` 或 `.xcodeproj` 中的版本字段。
- GitHub Actions 的 iOS job 检查 XcodeGen 工程同步，动态选择可用 iPhone 模拟器并运行单元测试（使用 ad-hoc 签名以支持 Keychain 测试）；测试结果保留为 artifact。
- 发布前必须确保 `main` 分支的 GitHub Actions 构建通过（`.github/workflows/build.yml`）。
- 使用语义化版本标签触发发布：`git tag v<major>.<minor>` 并推送。
- 打标签前必须完成以下检查：
  1. `xcodegen generate` 后工程无未同步变更（`git diff --exit-code TodoLite.xcodeproj/`）
  2. iOS 和 macOS 双平台 `xcodebuild` 构建通过
  3. 测试通过（`xcodebuild ... test`）

## 代理工作流

- 修改文档或行为前，先检查当前代码。
- 尊重用户未提交的改动。不要回滚无关文件。
- 除非用户要求，不要自动 commit。
- 代码变更后，在声称完成前运行最相关的 build 或 test 命令。仅文档变更时，至少检查变更文件并运行 `git diff --check`。
- 如果修改 `project.yml`，运行 `xcodegen generate`，然后验证生成的工程变更。
- 同步规则：修改 `AGENTS.md` 或 `CLAUDE.md` 中任意一份代理说明时，必须检查另一份文件，并保持两者的项目事实、命令、工作流规则和约定同步。
