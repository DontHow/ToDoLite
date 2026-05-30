# 办他 / TodoLite

办他是一个 Local First 的原生 SwiftUI 待办应用，面向个人日常任务收集、整理和推进。应用支持 iOS、macOS 和 iOS Widget，数据以 JSON 文件保存，iCloud Documents 可用于跨设备同步。

## 当前功能

- 快速新建任务，支持 `@项目`、`#标签`、`^日期` 规则解析
- 可选 AI 解析自然语言任务，兼容 OpenAI Chat Completions 风格接口
- Today 工作台：关注、建议、逾期、即将到来
- 收件箱、三列看板、搜索、项目、标签、已完成、归档
- 已完成任务按周分组，并可用 LLM 生成中文周报
- iOS Widget 显示今日关注任务数量和前 3 条标题
- macOS 菜单栏入口显示今日关注任务
- 字体大小偏好设置

## 数据模型

核心任务模型为 `TodoItem`：

- `title` / `description`
- `status`: `inbox`、`doing`、`done`、`archived`
- `projectId`
- `tagIds`
- `scheduledAt`、`dueAt`
- `createdAt`、`updatedAt`、`completedAt`
- `version`

Today 不是任务字段，而是当天的关注集合，保存在 `meta/focus_yyyy-mm-dd.json`。任务是否出现在 Today 页面由 `TodoStore` 的派生集合决定：

- **关注**：当天 FocusSet 中的未完成、未归档任务
- **建议**：截止日期为今天，且未进入关注
- **逾期**：截止日期早于今天，且未进入关注
- **即将到来**：截止日期晚于今天，且未进入关注

## 存储与同步

文件系统是事实源。应用不使用 SwiftData 或 Core Data。

默认目录结构：

```text
iCloud Drive/TodoLite/
  tasks/task_<id>.json
  projects/project_<id>.json
  tags/tag_<id>.json
  trash/
  archive/
  conflicts/
  meta/
    focus_yyyy-mm-dd.json
  config/
    llm_config.json
```

如果 iCloud 容器不可用，`FileSystemManager` 会回退到本地 Documents 目录。搜索索引保存在 Application Support 下的 SQLite FTS5 数据库，只用于搜索，不是权威数据源。

## 架构

```text
View
  -> TodoStore (@Observable)
  -> Repository actor
  -> FileSystemManager actor
  -> JSON files
```

主要目录：

```text
TodoLite/
  App/                 应用入口、平台导航、macOS 菜单栏
  Features/            Today、Inbox、Board、Search、Projects、Settings
  Shared/
    Models/            Codable 数据模型
    Store/             TodoStore
    Repository/        JSON 仓库 actor
    FileSystem/        iCloud/local 文件读写与监听
    Search/            SQLite FTS5 搜索索引
    Parser/            规则解析与日期解析
    LLM/               LLM 配置、调用和解析
    Widget/            App Group Widget 数据同步
  Resources/           Info.plist、entitlements
TodoLiteWidget/        WidgetKit 扩展
Tests/                 单元测试
Tools/                 工具脚本
```

## 开发环境

- Xcode 15 或更新版本
- Swift 5.9
- iOS 17.0+
- macOS 14.0+
- XcodeGen

项目由 `project.yml` 生成：

```bash
xcodegen generate
```

## 构建

```bash
# iOS
xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# macOS
xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-macOS \
  -destination 'platform=macOS' \
  build
```

## 测试

```bash
xcodebuild -project TodoLite.xcodeproj \
  -scheme TodoLite-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

测试覆盖模型 Codable、状态迁移、规则解析、日期解析和 `TodoStore` 派生集合。

## LLM 配置

设置页提供 LLM 配置入口：

- API 地址，默认 `https://api.openai.com/v1`
- API 密钥
- 模型名称，默认 `gpt-4o-mini`

LLM 仅用于把自然语言解析为结构化任务，以及根据已完成任务生成周报。LLM 不直接写入文件系统，最终保存仍通过 `TodoStore` 和 Repository。

## 设计原则

- Local First，文件系统为事实源
- UI 不直接读写文件
- SQLite 只做搜索索引
- iCloud 同步与业务逻辑解耦
- 数据安全优先，写入使用原子写入和版本冲突保护
- 界面遵循 SwiftUI 原生平台行为，使用 SF Symbols 和系统材质
