# TodoLite 完整方案（MVP v1）

## 产品定位

TodoLite 是一个：

- 原生 SwiftUI 多平台 Todo App
- 面向个人用户
- Local First
- 文件事实源（File Source of Truth）
- iCloud 自动同步
- macOS + iOS 共用核心架构

核心目标：

- 快速记录
- 稳定同步
- 低心智负担
- 高可控性

不是：

- AI Agent
- 团队协作平台
- 复杂 GTD 系统
- 项目管理 SaaS

---

# 一、产品能力范围

## MVP 功能

### Todo

- 新建
- 编辑
- 删除
- 完成
- 归档
- 拖拽状态
- 搜索
- 标签
- 项目
- Today
- Board

---

### 状态

```swift
enum TodoStatus: String, Codable, CaseIterable {
    case inbox
    case next
    case doing
    case waiting
    case blocked
    case someday
    case done
    case cancelled
    case archived
}
```

---

### 优先级

```swift
enum TodoPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
}
```

---

### 时间字段

- scheduledAt
- dueAt
- createdAt
- updatedAt
- completedAt

不做：

- 系统提醒
- 推送通知
- 日历同步

---

### Today 规则

Today 包含：

1. scheduledAt 是今天
2. dueAt 今天或已过期
3. 手动 Pin Today
4. status 不属于 done / cancelled / archived

---

### 项目（Project）

支持：

- 名称
- emoji/icon
- color
- archived

不支持：

- 项目分组
- 项目层级
- 多项目归属

---

### 标签（Tag）

支持：

- 彩色标签
- 自动统计

不支持：

- 层级标签
- 智能标签

---

### 看板（Board）

固定按状态分列：

Inbox / Next / Doing / Waiting / Blocked / Someday / Done

支持拖拽修改状态。

---

# 二、明确不做

第一版严格禁止：

- 协作
- 登录
- 后端
- CloudKit DB
- AI 自动规划
- AI 自动分类
- GPT 自动写入
- 子任务
- 附件
- Apple Watch
- 多用户
- CRDT
- 日历视图
- 提醒系统
- Markdown 事实源

---

# 三、技术架构

## 技术栈

| 层     | 技术              |
| ------ | ----------------- |
| UI     | SwiftUI           |
| 平台   | iOS + macOS       |
| 数据   | JSON              |
| 同步   | iCloud Documents  |
| 状态管理 | Observation       |
| 文件监听 | NSMetadataQuery   |
| 文件协调 | NSFileCoordinator |
| 搜索索引 | SQLite（仅索引）  |

---

## 核心原则

### 原则 1

文件系统才是事实源

不是 SwiftData / SQLite / 内存

---

### 原则 2

UI 禁止直接操作文件

流程：View → Repository → FileSystem

---

### 原则 3

同步层和业务层解耦

---

### 原则 4

SQLite 只做搜索索引，不是事实源。

---

# 四、目录结构

```
TodoLite/
├── App/
├── Features/
│   ├── Today/
│   ├── Inbox/
│   ├── Board/
│   ├── Projects/
│   ├── Search/
│   └── Settings/
├── Shared/
│   ├── Models/
│   ├── Store/
│   ├── Repository/
│   ├── FileSystem/
│   ├── Search/
│   ├── Parser/
│   └── Utils/
├── Resources/
└── README.md
```

---

# 五、iCloud 文件结构

```
iCloud Drive/
└── TodoLite/
    ├── tasks/
    ├── projects/
    ├── tags/
    ├── trash/
    ├── archive/
    ├── conflicts/
    └── meta/
```

---

## Todo 文件

```
tasks/task_01JABC.json
```

---

## Project 文件

```
projects/project_work.json
```

---

# 六、数据模型

## TodoItem

```swift
struct TodoItem: Codable, Identifiable {
    var id: String

    var title: String
    var description: String

    var status: TodoStatus
    var priority: TodoPriority

    var projectId: String?

    var tagIds: [String]

    var isPinnedToday: Bool

    var scheduledAt: Date?
    var dueAt: Date?

    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var version: Int
}
```

---

## Project

```swift
struct Project: Codable, Identifiable {
    var id: String

    var name: String

    var emoji: String
    var colorHex: String

    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date
}
```

---

## Tag

```swift
struct TagItem: Codable, Identifiable {
    var id: String

    var name: String
    var colorHex: String
}
```

---

# 七、自然语言解析（Quick Entry）

## 产品定位

不是 AI，而是规则解析器（Rule Based Parser）。

---

## 支持语法

| 语法        | 含义       |
| ----------- | ---------- |
| `@工作`     | project    |
| `#iOS`      | tag        |
| `!high`     | priority   |
| `^tomorrow` | 日期       |

---

## 示例

输入：

```
提交 TestFlight @工作 #iOS !high ^tomorrow
```

输出：

```json
{
  "title": "提交 TestFlight",
  "project": "工作",
  "tags": ["iOS"],
  "priority": "high",
  "scheduledAt": "tomorrow"
}
```

---

## Parser 架构

```
Raw Input
↓
Tokenizer
↓
Syntax Parser
↓
Date Resolver
↓
TodoDraft
```

---

# 八、同步机制

## iCloud Container

```swift
FileManager.default.url(
    forUbiquityContainerIdentifier: nil
)
```

---

## 文件读写

统一使用 NSFileCoordinator。

---

## 文件监听

使用 NSMetadataQuery 监听新增、修改、删除。

---

## 冲突策略

第一版：最后修改覆盖 + 保留 conflict backup。

冲突文件：

```
conflicts/task_xxx_conflict_20260526.json
```

---

# 九、搜索系统

## 搜索能力

支持标题、描述、标签、项目。

---

## 搜索实现

SQLite 仅做索引。

流程：JSON 文件 → Indexer → SQLite FTS → Search Query

---

# 十、macOS 设计

## 布局

NavigationSplitView

Sidebar → Task List → Task Detail

---

## Sidebar

- Today
- Inbox
- Board
- Projects
- Tags
- Done
- Archive

---

## 快捷键

- ⌘N 新建
- ⌘K 搜索
- ⌘1 Today
- ⌘2 Inbox
- ⌘⌫ 删除

---

# 十一、iOS 设计

## Tab

Today / Inbox / Board / Search / Settings

---

## 移动端优先级

1. 快速新增
2. 快速完成
3. Today 浏览

不是复杂管理。

---

# 十二、Widget / MenuBar

## macOS

支持 MenuBar Extra：

- 快速新增
- 查看 Today

---

## iOS Widget

支持：

- Today 数量
- 今日任务

---

# 十三、MVP 开发顺序

## 第一阶段

核心数据层：Models / Repository / FileSystem / JSON Store

---

## 第二阶段

本地 CRUD：Task List / Task Detail / Create/Edit/Delete

---

## 第三阶段

iCloud：iCloud Container / NSMetadataQuery / 文件监听

---

## 第四阶段

Today + Board：Today / Board / Drag & Drop

---

## 第五阶段

Parser + Search：Quick Entry / SQLite FTS

---

## 第六阶段

体验层：快捷键 / MenuBar / Widget / 动画

---

# 十四、最重要的原则

## 第一优先级

数据永不丢失

---

## 第二优先级

同步稳定

---

## 第三优先级

输入速度

---

## 最后才是

漂亮 UI

---

# 十五、最终产品定义

TodoLite：

一个 Local First / 原生 SwiftUI / iCloud 文件同步 / 单用户 / 高可控 / 低复杂度 / 高可靠性 的个人 Todo App。

并且：文件系统是事实源，AI 不参与事实写入，规则解析替代 LLM Agent。
