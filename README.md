# 办他 / TodoLite

办他是一个 Local First 的原生 SwiftUI 待办应用，面向个人日常任务收集、整理和推进。应用支持 iOS、macOS 和 iOS Widget，数据以 JSON 文件保存，iCloud Documents 可用于跨设备同步。

## 当前功能

- 详细任务表单，支持 `@项目`、`#标签`、`^日期` 规则解析
- 可选 AI 解析自然语言任务，兼容 OpenAI Chat Completions 风格接口
- Today 工作台：关注、建议、逾期、即将到来
- 收件箱、三列看板、搜索、项目、标签、已完成、归档
- 已完成任务按周分组，周报提供可编辑预览，确认发送后使用 LLM 生成
- iOS Widget 显示今日关注任务数量和前 3 条标题
- macOS 菜单栏入口显示今日关注任务
- 跟随系统字体或选择自定义大小；手机看板使用单列状态切换

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

LLM API 密钥仅保存在本机钥匙串，不写入 JSON，也不通过 iCloud Documents 同步；其他设备需要单独配置。旧配置中的明文密钥会在成功迁移到钥匙串后从当前配置文件中移除。

任务更新使用文件协调内的版本校验，冲突编辑保存在 `conflicts/` 中。损坏或无法读取的文件不会被当成空数据覆盖；启动加载失败会显示错误并提供重试入口。

本地回退数据迁回 iCloud 时逐个文件合并：补齐缺失项，同名但内容不同的本地副本进入冲突备份，保留云端原文件。迁移回执支持中断续传，避免已删除任务在下次启动时重新导入。iCloud 尚未下载的文件会先请求下载，不作为缺失项覆盖。

设置中的“回收站与备份”支持恢复误删任务，以及导出/导入 JSON 数据备份。备份包含任务、项目、标签、历史关注、回收站和这三类记录的冲突副本，不包含 AI 配置和 API Key，单份备份最大 50 MB；导出协调读取本机已下载文件，并在文件集合变化时重试。导入只补齐缺失记录，已有内容保持不变，失败后可重试。未下载的云端文件会阻止导出，避免得到不完整的备份。删除不会立即销毁任务，归档仍可在“已归档”中查看。

“冲突副本”区可比较任务、项目、标签的当前内容与备份，并恢复为独立副本。重复恢复会复用同一副本，保留恢复后的编辑。恢复项目和标签不会迁移已有任务关联。导出格式为 v2，仍支持导入旧 v1 备份；配置等其他冲突文件不进入备份。


iOS 设置中可进入项目、标签、已完成和归档；macOS 菜单栏新建任务及 ⌘N 可直接打开创建表单。

搜索支持中文中间词、单字和混合语言关键词。iOS 安装包包含 Widget 扩展，双方共用关注快照与 App Group；Widget 到次日会清除昨日关注显示。

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

测试覆盖模型和状态迁移、规则/日期边界、Store 派生集合、并发持久化、今日关注并发增删、项目/标签旧编辑保护、草稿幂等重试与部分保存恢复、密钥迁移、云端合并、中文搜索、Widget 跨日、回收站与备份恢复、备份大小边界与并发快照、Store 同步/加载交错、冲突副本恢复与备份版本兼容，以及使用临时会话文件验证的周报来源/日期筛选。

## 发布

推送 `v<major>.<minor>` 或 `v<major>.<minor>.<patch>` 标签会触发 GitHub Release。发布任务会签名并公证 macOS 应用，然后上传以下文件：

- `TodoLite-<version>.dmg`
- `TodoLite-<version>.zip`
- `CHANGELOG-<version>.md`

仓库需要配置以下 GitHub Actions Secrets；缺少任意一项时发布任务会停止，避免发布无法通过 macOS Gatekeeper 检查的安装包：

- `MACOS_CERTIFICATE`：Developer ID Application `.p12` 文件的 Base64 内容
- `MACOS_CERTIFICATE_PASSWORD`：导出 `.p12` 时设置的密码
- `MACOS_PROVISIONING_PROFILE`：包含 iCloud 和 App Group 权限的 Developer ID provisioning profile 的 Base64 内容
- `APPSTORE_API_KEY_ID`：App Store Connect API Key ID
- `APPSTORE_ISSUER_ID`：App Store Connect Issuer ID
- `APPSTORE_API_PRIVATE_KEY_BASE64`：App Store Connect `.p8` 私钥的 Base64 内容

在 macOS 上可用以下命令生成 Base64 内容：

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i TodoLite.provisionprofile | pbcopy
base64 -i AuthKey_<KEY_ID>.p8 | pbcopy
```

发布任务会检查 `project.yml` 生成的 `CFBundleShortVersionString` 是否与标签版本一致，不一致时停止发布。

## LLM 配置

设置页提供 LLM 配置入口：

- API 地址，默认 `https://api.openai.com/v1`
- API 密钥
- 模型名称，默认 `gpt-4o-mini`

macOS 周报可选补充 Claude Code、Codex 或 Cursor 的本机记录，默认不读取；选择来源后仅提取所选周的可识别消息，发送前可检查和编辑。

LLM 仅用于把自然语言解析为结构化任务，以及根据已完成任务生成周报。LLM 不直接写入文件系统，最终保存仍通过 `TodoStore` 和 Repository。

## 设计原则

- Local First，文件系统为事实源
- UI 不直接读写文件
- SQLite 只做搜索索引
- iCloud 同步与业务逻辑解耦
- 数据安全优先，写入使用原子写入和版本冲突保护
- 界面遵循 SwiftUI 原生平台行为，使用 SF Symbols 和系统材质

GitHub Actions 会检查 XcodeGen 工程同步，并在可用 iPhone 模拟器上运行单元测试；发布流程依赖该检查通过。
